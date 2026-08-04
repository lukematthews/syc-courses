import { generateKeyPairSync, verify } from 'node:crypto'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { buildApp } from '../src/app.js'
import type { LicensingConfig } from '../src/config.js'
import { invitationDigest } from '../src/crypto.js'
import type { Club, Invitation } from '../src/models.js'
import { InMemoryRepository } from './inMemoryRepository.js'

const code = 'DEV-SAIL-ONLY-7K2M'
const installationId = '11111111-1111-4111-8111-111111111111'
const testSigningKey = generateKeyPairSync('ed25519')
const privateKey = testSigningKey.privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64')
const clock = new Date('2026-08-05T00:00:00Z')
const config: LicensingConfig = {
  mongoUrl: 'mongodb://unused', mongoDatabase: 'test', invitationLookupSecret: 'TEST-ONLY-invitation-secret',
  refreshLookupSecret: 'TEST-ONLY-refresh-secret', signingPrivateKeyPkcs8: privateKey,
  signingKeyId: 'development-2026-01', currentDays: 14, expiryDays: 30, graceDays: 60,
  minimumAppVersion: '1.0.0', port: 3000, host: '127.0.0.1', trustProxy: true,
}
type ActivationBody = { entitlement: { payload: string; signature: string }; refreshCredential: string }
let repository: InMemoryRepository
let app: ReturnType<typeof buildApp>

function seed(options: { invitationStatus?: 'active' | 'inactive'; clubStatus?: 'active' | 'inactive'; validUntil?: Date; limit?: number; perpetual?: boolean } = {}) {
  const club: Club = {
    id: 'syc', name: 'Development Sailing Club', status: options.clubStatus ?? 'active', licenceType: options.perpetual ? 'perpetual' : 'term',
    licenceStartsAt: new Date('2020-01-01T00:00:00Z'), licenceEndsAt: new Date('2099-01-01T00:00:00Z'),
    perpetualAccess: options.perpetual ?? false, updatesUntil: new Date('2099-01-01T00:00:00Z'),
    enabledFeatures: ['coursePackUpdates'], permittedPackIds: ['sandringham-yacht-club-2025-2028'], createdAt: clock, updatedAt: clock,
  }
  const invitation: Invitation = {
    id: 'invite-1', clubId: club.id, codeDigest: invitationDigest(config.invitationLookupSecret, code), codeHint: '…7K2M',
    status: options.invitationStatus ?? 'active', validFrom: new Date('2020-01-01T00:00:00Z'), validUntil: options.validUntil ?? new Date('2099-01-01T00:00:00Z'),
    activationLimit: options.limit ?? null, activationCount: 0, policyVersion: 1, createdAt: clock, updatedAt: clock,
  }
  repository.clubs.push(club); repository.invitations.push(invitation)
}

function activation(overrides: Record<string, unknown> = {}) {
  return app.inject({ method: 'POST', url: '/v1/activations', headers: { 'content-type': 'application/json', 'x-forwarded-for': '203.0.113.20' }, payload: { invitationCode: code, installationId, appVersion: '1.0.0', platform: 'ios', ...overrides } })
}
function errorCode(response: { json(): unknown }) { return (response.json() as { error: { code: string } }).error.code }

beforeEach(() => { repository = new InMemoryRepository(); app = buildApp({ repository, config, now: () => new Date(clock) }) })
afterEach(async () => { await app.close() })

describe('Railway licensing API', () => {
  it('reports database-backed health', async () => { expect((await app.inject({ method: 'GET', url: '/v1/health' })).statusCode).toBe(200) })
  it('activates, signs exact bytes, stores no plaintext invitation, and is idempotent', async () => {
    seed(); const first = await activation(); expect(first.statusCode).toBe(201)
    const body = first.json() as ActivationBody
    expect(verify(null, Buffer.from(body.entitlement.payload, 'base64url'), testSigningKey.publicKey, Buffer.from(body.entitlement.signature, 'base64url'))).toBe(true)
    expect(body.refreshCredential).toBeTruthy(); expect(JSON.stringify(repository.invitations)).not.toContain(code)
    expect((await activation()).statusCode).toBe(201); expect(repository.installations).toHaveLength(1); expect(repository.entitlements).toHaveLength(2)
    expect(repository.entitlements[0].status).toBe('replaced')
  })
  it('rejects malformed and unsupported requests with stable codes', async () => {
    expect(errorCode(await activation({ installationId: 'bad' }))).toBe('MALFORMED_REQUEST')
    expect(errorCode(await activation({ appVersion: '0.9.0' }))).toBe('UNSUPPORTED_APP_VERSION')
  })
  it.each([
    [{}, 'WRONG', 'INVALID_INVITATION'],
    [{ invitationStatus: 'inactive' as const }, code, 'INVITATION_INACTIVE'],
    [{ validUntil: new Date('2020-01-01T00:00:00Z') }, code, 'INVITATION_EXPIRED'],
    [{ clubStatus: 'inactive' as const }, code, 'CLUB_LICENCE_INACTIVE'],
  ])('rejects invitation/club policy %#', async (options, invitationCode, expected) => {
    seed(options); expect(errorCode(await activation({ invitationCode }))).toBe(expected)
  })
  it('atomically models invitation activation thresholds', async () => {
    seed({ limit: 1 }); expect((await activation()).statusCode).toBe(201)
    expect(errorCode(await activation({ installationId: '22222222-2222-4222-8222-222222222222' }))).toBe('ACTIVATION_LIMIT_REACHED')
  })
  it('rate limits bursts by privacy-preserving subject digest', async () => {
    seed(); for (let index = 0; index < 10; index++) await activation()
    expect(errorCode(await activation())).toBe('RATE_LIMITED'); expect([...repository.rateLimits.keys()][0]).not.toContain('203.0.113.20')
  })
  it('refreshes with the opaque credential and rejects tampering', async () => {
    seed(); const activated = (await activation()).json() as ActivationBody
    const refresh = (credential: string) => app.inject({ method: 'POST', url: '/v1/entitlements/refresh', payload: { refreshCredential: credential, installationId, appVersion: '1.0.0' } })
    expect((await refresh(activated.refreshCredential)).statusCode).toBe(200)
    expect(errorCode(await refresh(`${activated.refreshCredential}x`))).toBe('INVALID_ENTITLEMENT')
  })
  it('invitation rotation blocks new activation while existing refresh continues', async () => {
    seed(); const activated = (await activation()).json() as ActivationBody; repository.invitations[0].status = 'inactive'
    expect(errorCode(await activation({ installationId: '33333333-3333-4333-8333-333333333333' }))).toBe('INVITATION_INACTIVE')
    const response = await app.inject({ method: 'POST', url: '/v1/entitlements/refresh', payload: { refreshCredential: activated.refreshCredential, installationId, appVersion: '1.0.0' } })
    expect(response.statusCode).toBe(200)
  })
  it('issues perpetual access separately and removes expired update services', async () => {
    seed({ perpetual: true }); repository.clubs[0].updatesUntil = new Date('2020-01-01T00:00:00Z')
    const body = (await activation()).json() as ActivationBody
    const payload = JSON.parse(Buffer.from(body.entitlement.payload, 'base64url').toString('utf8'))
    expect(payload.perpetualAccess).toBe(true); expect(payload.expiresAt).toBeNull(); expect(payload.enabledFeatures).not.toContain('coursePackUpdates')
  })
})
