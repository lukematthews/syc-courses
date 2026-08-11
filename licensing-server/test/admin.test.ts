import { generateKeyPairSync } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { AdminRepository, ClubAdminMembership, CoursePackDraft, PublishedCoursePack } from '../src/admin.js'
import { buildApp } from '../src/app.js'
import type { LicensingConfig } from '../src/config.js'
import { InMemoryRepository } from './inMemoryRepository.js'

const privateKey = generateKeyPairSync('ed25519').privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64')
const config: LicensingConfig = {
  mongoUrl: 'mongodb://unused', mongoDatabase: 'test', invitationLookupSecret: 'test-invitation-secret',
  refreshLookupSecret: 'test-refresh-secret', signingPrivateKeyPkcs8: privateKey, signingKeyId: 'test',
  currentDays: 14, expiryDays: 30, graceDays: 60, minimumAppVersion: '1.0.0', port: 3000,
  host: '127.0.0.1', trustProxy: true, adminWebOrigins: ['http://localhost:5173'],
}

class AdminMemory implements AdminRepository {
  membership: ClubAdminMembership | null = { subject: 'auth0|owner', clubId: 'syc', role: 'owner', status: 'active', createdAt: new Date(), updatedAt: new Date() }
  draft: CoursePackDraft | null = null
  published: PublishedCoursePack[] = []
  async findAdminMembership(subject: string) { return this.membership?.subject === subject && this.membership.status === 'active' ? this.membership : null }
  async getCoursePackDraft(clubId: string) { return this.draft?.clubId === clubId ? this.draft : null }
  async saveCoursePackDraft(clubId: string, payload: Record<string, unknown>, subject: string, expectedRevision: number | null, now: Date) {
    if (this.draft && expectedRevision !== this.draft.revision) return 'conflict' as const
    this.draft = { clubId, payload, updatedBy: subject, updatedAt: now, revision: (this.draft?.revision ?? 0) + 1 }
    return this.draft
  }
  async publishCoursePack(clubId: string, subject: string, version: string, now: Date) {
    if (!this.draft) return null
    const item = { id: `${clubId}:${version}`, clubId, version, payload: this.draft.payload, publishedBy: subject, publishedAt: now }
    this.published.push(item); return item
  }
}

let app: ReturnType<typeof buildApp>
let admin: AdminMemory
const auth = { authorization: 'Bearer valid' }

beforeEach(() => {
  admin = new AdminMemory()
  app = buildApp({ repository: new InMemoryRepository(), adminRepository: admin, config, adminAuthenticator: async (request) => {
    if (request.headers.authorization !== 'Bearer valid') throw new Error('invalid')
    return { subject: 'auth0|owner' }
  } })
})
afterEach(async () => app.close())

describe('club administration API', () => {
  it('requires an authenticated active club membership', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/admin/course-pack' })).statusCode).toBe(403)
    admin.membership = null
    expect((await app.inject({ method: 'GET', url: '/v1/admin/course-pack', headers: auth })).statusCode).toBe(403)
  })

  it('creates, reads and revision-checks a draft', async () => {
    const created = await app.inject({ method: 'PUT', url: '/v1/admin/course-pack', headers: auth, payload: { revision: null, pack: { packId: 'syc', notices: [] } } })
    expect(created.statusCode).toBe(200)
    expect(created.json()).toMatchObject({ clubId: 'syc', role: 'owner', revision: 1 })
    expect((await app.inject({ method: 'GET', url: '/v1/admin/course-pack', headers: auth })).json()).toMatchObject({ revision: 1, pack: { packId: 'syc' } })
    expect((await app.inject({ method: 'PUT', url: '/v1/admin/course-pack', headers: auth, payload: { revision: 0, pack: { packId: 'stale' } } })).statusCode).toBe(409)
  })

  it('limits publishing to owners and publishers', async () => {
    await app.inject({ method: 'PUT', url: '/v1/admin/course-pack', headers: auth, payload: { revision: null, pack: { packId: 'syc' } } })
    admin.membership = { ...admin.membership!, role: 'editor' }
    expect((await app.inject({ method: 'POST', url: '/v1/admin/course-pack/publish', headers: auth, payload: { version: '2026.08.06' } })).statusCode).toBe(403)
    admin.membership = { ...admin.membership, role: 'publisher' }
    expect((await app.inject({ method: 'POST', url: '/v1/admin/course-pack/publish', headers: auth, payload: { version: '2026.08.06' } })).statusCode).toBe(201)
  })
})
