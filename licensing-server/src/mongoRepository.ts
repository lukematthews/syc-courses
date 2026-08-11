import { MongoClient, type Collection, type Db, type Document, type Filter } from 'mongodb'
import type { Club, EntitlementRecord, Installation, Invitation } from './models.js'
import type { CreateInstallationInput, InstallationResult, LicensingRepository } from './repository.js'
import type { AdminRepository, ClubAdminMembership, CoursePackDraft, PublishedCoursePack } from './admin.js'

interface RateLimitDocument { subjectDigest: string; windowStartedAt: Date; attemptCount: number; expiresAt: Date }

export class MongoLicensingRepository implements LicensingRepository, AdminRepository {
  private constructor(private readonly client: MongoClient, private readonly database: Db) {}

  static async connect(url: string, databaseName: string): Promise<MongoLicensingRepository> {
    const client = new MongoClient(url, { appName: 'syc-club-licensing-api', maxPoolSize: 10, minPoolSize: 0 })
    await client.connect()
    return new MongoLicensingRepository(client, client.db(databaseName))
  }

  private collection<T extends Document>(name: string): Collection<T> { return this.database.collection<T>(name) }
  private get clubs() { return this.collection<Club & Document>('clubs') }
  private get invitations() { return this.collection<Invitation & Document>('invitations') }
  private get installations() { return this.collection<Installation & Document>('installations') }
  private get entitlements() { return this.collection<EntitlementRecord & Document>('entitlements') }
  private get rateLimits() { return this.collection<RateLimitDocument & Document>('activationRateLimits') }
  private get adminMemberships() { return this.collection<ClubAdminMembership & Document>('clubAdminMemberships') }
  private get coursePackDrafts() { return this.collection<CoursePackDraft & Document>('coursePackDrafts') }
  private get publishedCoursePacks() { return this.collection<PublishedCoursePack & Document>('publishedCoursePacks') }

  async ensureIndexes(): Promise<void> {
    await Promise.all([
      this.clubs.createIndex({ id: 1 }, { unique: true, name: 'club_id_unique' }),
      this.invitations.createIndex({ id: 1 }, { unique: true, name: 'invitation_id_unique' }),
      this.invitations.createIndex({ codeDigest: 1 }, { unique: true, name: 'invitation_digest_unique' }),
      this.invitations.createIndex({ clubId: 1, status: 1 }, { name: 'invitation_club_status' }),
      this.installations.createIndex({ id: 1 }, { unique: true, name: 'installation_id_unique' }),
      this.installations.createIndex({ publicInstallationId: 1, clubId: 1 }, { unique: true, name: 'installation_public_club_unique' }),
      this.installations.createIndex({ refreshCredentialDigest: 1 }, { unique: true, name: 'refresh_digest_unique' }),
      this.installations.createIndex({ clubId: 1, status: 1 }, { name: 'installation_club_status' }),
      this.entitlements.createIndex({ id: 1 }, { unique: true, name: 'entitlement_id_unique' }),
      this.entitlements.createIndex({ installationId: 1, status: 1 }, { name: 'entitlement_installation_status' }),
      this.rateLimits.createIndex({ subjectDigest: 1, windowStartedAt: 1 }, { unique: true, name: 'rate_subject_window_unique' }),
      this.rateLimits.createIndex({ expiresAt: 1 }, { expireAfterSeconds: 0, name: 'rate_expiry_ttl' }),
      this.adminMemberships.createIndex({ subject: 1 }, { unique: true, name: 'admin_subject_unique' }),
      this.adminMemberships.createIndex({ clubId: 1, status: 1 }, { name: 'admin_club_status' }),
      this.coursePackDrafts.createIndex({ clubId: 1 }, { unique: true, name: 'course_pack_draft_club_unique' }),
      this.publishedCoursePacks.createIndex({ clubId: 1, version: 1 }, { unique: true, name: 'published_pack_club_version_unique' }),
    ])
  }

  async ping(): Promise<void> { await this.database.command({ ping: 1 }) }
  async close(): Promise<void> { await this.client.close() }

  async consumeRateLimit(subjectDigest: string, windowStartedAt: Date, limit: number): Promise<boolean> {
    const expiresAt = new Date(windowStartedAt.getTime() + 2 * 86_400_000)
    try {
      const result = await this.rateLimits.findOneAndUpdate(
        { subjectDigest, windowStartedAt },
        { $inc: { attemptCount: 1 }, $setOnInsert: { expiresAt } },
        { upsert: true, returnDocument: 'after' },
      )
      return (result?.attemptCount ?? 1) <= limit
    } catch (error) {
      if (!isDuplicateKey(error)) throw error
      const result = await this.rateLimits.findOneAndUpdate(
        { subjectDigest, windowStartedAt }, { $inc: { attemptCount: 1 } }, { returnDocument: 'after' },
      )
      return (result?.attemptCount ?? limit + 1) <= limit
    }
  }

  async findInvitationByDigest(codeDigest: string): Promise<Invitation | null> {
    return this.invitations.findOne({ codeDigest }, { projection: { _id: 0 } })
  }

  async findClub(id: string): Promise<Club | null> { return this.clubs.findOne({ id }, { projection: { _id: 0 } }) }

  async createOrGetInstallation(input: CreateInstallationInput): Promise<InstallationResult> {
    const existing = await this.installations.findOne(
      { publicInstallationId: input.publicInstallationId, clubId: input.clubId }, { projection: { _id: 0 } },
    )
    if (existing) return { kind: 'existing', installation: existing }

    // This reservation is atomic on the invitation document and works on a standalone Mongo server.
    // A crash can conservatively consume a slot, but concurrent requests cannot exceed the threshold.
    const invitation = await this.invitations.findOneAndUpdate(
      {
        id: input.invitationId,
        $or: [{ activationLimit: null }, { activationLimit: { $exists: false } }, { $expr: { $lt: ['$activationCount', '$activationLimit'] } }],
      } as Filter<Invitation & Document>,
      { $inc: { activationCount: 1 }, $set: { updatedAt: input.now } },
      { returnDocument: 'after' },
    )
    if (!invitation) return { kind: 'limitReached' }

    const installation: Installation = {
      id: input.id, publicInstallationId: input.publicInstallationId, clubId: input.clubId,
      invitationId: input.invitationId, firstActivatedAt: input.now, lastRefreshedAt: input.now,
      appVersion: input.appVersion, platform: input.platform, status: 'active',
      refreshCredentialDigest: input.refreshCredentialDigest, createdAt: input.now, updatedAt: input.now,
    }
    try {
      await this.installations.insertOne(installation)
      return { kind: 'created', installation }
    } catch (error) {
      await this.invitations.updateOne({ id: input.invitationId, activationCount: { $gt: 0 } }, { $inc: { activationCount: -1 } })
      if (!isDuplicateKey(error)) throw error
      const winner = await this.installations.findOne(
        { publicInstallationId: input.publicInstallationId, clubId: input.clubId }, { projection: { _id: 0 } },
      )
      if (!winner) throw error
      return { kind: 'existing', installation: winner }
    }
  }

  async rotateInstallationCredential(id: string, digest: string, appVersion: string, platform: string, now: Date): Promise<void> {
    await this.installations.updateOne({ id }, { $set: { refreshCredentialDigest: digest, appVersion, platform, updatedAt: now } })
  }

  async findInstallationForRefresh(publicInstallationId: string, refreshCredentialDigest: string): Promise<Installation | null> {
    return this.installations.findOne({ publicInstallationId, refreshCredentialDigest }, { projection: { _id: 0 } })
  }

  async recordRefresh(id: string, appVersion: string, now: Date): Promise<void> {
    await this.installations.updateOne({ id }, { $set: { lastRefreshedAt: now, appVersion, updatedAt: now } })
  }

  async saveEntitlement(record: EntitlementRecord): Promise<void> {
    await this.entitlements.insertOne(record)
    await this.entitlements.updateMany(
      { installationId: record.installationId, status: 'active', id: { $ne: record.id } },
      { $set: { status: 'replaced', replacedById: record.id } },
    )
  }

  async findAdminMembership(subject: string): Promise<ClubAdminMembership | null> {
    return this.adminMemberships.findOne({ subject, status: 'active' }, { projection: { _id: 0 } })
  }

  async getCoursePackDraft(clubId: string): Promise<CoursePackDraft | null> {
    return this.coursePackDrafts.findOne({ clubId }, { projection: { _id: 0 } })
  }

  async saveCoursePackDraft(clubId: string, payload: Record<string, unknown>, subject: string, expectedRevision: number | null, now: Date): Promise<CoursePackDraft | 'conflict'> {
    const existing = await this.coursePackDrafts.findOne({ clubId })
    if (existing && existing.revision !== expectedRevision) return 'conflict'
    const revision = (existing?.revision ?? 0) + 1
    const draft: CoursePackDraft = { clubId, revision, payload, updatedBy: subject, updatedAt: now }
    try {
      const result = await this.coursePackDrafts.replaceOne({ clubId, ...(existing ? { revision: existing.revision } : {}) }, draft, { upsert: !existing })
      if (existing && result.matchedCount === 0) return 'conflict'
    } catch (error) {
      if (isDuplicateKey(error)) return 'conflict'
      throw error
    }
    return draft
  }

  async publishCoursePack(clubId: string, subject: string, version: string, now: Date): Promise<PublishedCoursePack | null> {
    const draft = await this.getCoursePackDraft(clubId)
    if (!draft) return null
    const published: PublishedCoursePack = { id: `${clubId}:${version}`, clubId, version, payload: draft.payload, publishedBy: subject, publishedAt: now }
    await this.publishedCoursePacks.insertOne(published)
    return published
  }
}

function isDuplicateKey(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: unknown }).code === 11000
}
