import type { Club, EntitlementRecord, Installation, Invitation } from '../src/models.js'
import type { CreateInstallationInput, InstallationResult, LicensingRepository } from '../src/repository.js'

export class InMemoryRepository implements LicensingRepository {
  clubs: Club[] = []
  invitations: Invitation[] = []
  installations: Installation[] = []
  entitlements: EntitlementRecord[] = []
  rateLimits = new Map<string, number>()
  async ensureIndexes() {}
  async ping() {}
  async close() {}
  async consumeRateLimit(subject: string, window: Date, limit: number) {
    const key = `${subject}:${window.toISOString()}`; const count = (this.rateLimits.get(key) ?? 0) + 1
    this.rateLimits.set(key, count); return count <= limit
  }
  async findInvitationByDigest(digest: string) { return this.invitations.find((value) => value.codeDigest === digest) ?? null }
  async findClub(id: string) { return this.clubs.find((value) => value.id === id) ?? null }
  async createOrGetInstallation(input: CreateInstallationInput): Promise<InstallationResult> {
    const existing = this.installations.find((value) => value.publicInstallationId === input.publicInstallationId && value.clubId === input.clubId)
    if (existing) return { kind: 'existing', installation: existing }
    const invitation = this.invitations.find((value) => value.id === input.invitationId)!
    if (invitation.activationLimit !== null && invitation.activationCount >= invitation.activationLimit) return { kind: 'limitReached' }
    invitation.activationCount += 1
    const installation: Installation = {
      id: input.id, publicInstallationId: input.publicInstallationId, clubId: input.clubId, invitationId: input.invitationId,
      firstActivatedAt: input.now, lastRefreshedAt: input.now, appVersion: input.appVersion, platform: input.platform,
      status: 'active', refreshCredentialDigest: input.refreshCredentialDigest, createdAt: input.now, updatedAt: input.now,
    }
    this.installations.push(installation); return { kind: 'created', installation }
  }
  async rotateInstallationCredential(id: string, digest: string, appVersion: string, platform: string, now: Date) {
    Object.assign(this.installations.find((value) => value.id === id)!, { refreshCredentialDigest: digest, appVersion, platform, updatedAt: now })
  }
  async findInstallationForRefresh(publicId: string, digest: string) { return this.installations.find((value) => value.publicInstallationId === publicId && value.refreshCredentialDigest === digest) ?? null }
  async recordRefresh(id: string, appVersion: string, now: Date) { Object.assign(this.installations.find((value) => value.id === id)!, { lastRefreshedAt: now, appVersion, updatedAt: now }) }
  async saveEntitlement(record: EntitlementRecord) {
    for (const value of this.entitlements) if (value.installationId === record.installationId && value.status === 'active') Object.assign(value, { status: 'replaced', replacedById: record.id })
    this.entitlements.push(record)
  }
}
