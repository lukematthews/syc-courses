import { randomUUID } from 'node:crypto'
import Fastify, { type FastifyInstance } from 'fastify'
import type { LicensingConfig } from './config.js'
import { invitationDigest, randomToken, refreshDigest, signEntitlement } from './crypto.js'
import type { Club, EntitlementPayload, EntitlementRecord, Installation } from './models.js'
import type { LicensingRepository } from './repository.js'

type JsonObject = Record<string, unknown>
export interface AppDependencies { repository: LicensingRepository; config: LicensingConfig; now?: () => Date }

class PrivacyLogController extends Fastify.LogController {
  constructor() { super({ disableRequestLogging: true }) }
}

export function buildApp({ repository, config, now = () => new Date() }: AppDependencies): FastifyInstance {
  const app = Fastify({
    trustProxy: config.trustProxy,
    bodyLimit: 16 * 1024,
    logController: new PrivacyLogController(),
    logger: process.env.NODE_ENV === 'test' ? false : {
      level: process.env.LOG_LEVEL ?? 'info',
      redact: ['req.headers.authorization', 'req.body', 'res.body'],
    },
  })

  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header('cache-control', 'no-store')
    reply.header('x-content-type-options', 'nosniff')
    return payload
  })

  app.get('/v1/health', async (_request, reply) => {
    try { await repository.ping(); return { status: 'ok', schemaVersion: 1 } }
    catch { return reply.code(503).send(errorBody('TEMPORARY_SERVER_ERROR', 'The licensing service is temporarily unavailable.')) }
  })

  app.post('/v1/activations', async (request, reply) => {
    const body = objectBody(request.body)
    if (!body || typeof body.invitationCode !== 'string' || !validInstallationId(body.installationId)
      || !validVersion(body.appVersion) || !['ios', 'macos'].includes(String(body.platform))) {
      return reply.code(400).send(errorBody('MALFORMED_REQUEST', 'The activation request is invalid.'))
    }
    if (versionBelow(body.appVersion, config.minimumAppVersion)) {
      return reply.code(400).send(errorBody('UNSUPPORTED_APP_VERSION', 'This app version is not supported.'))
    }

    const current = now()
    const window = new Date(current); window.setUTCSeconds(0, 0)
    const rateSubject = invitationDigest(config.invitationLookupSecret, `rate:${request.ip}`)
    if (!await repository.consumeRateLimit(rateSubject, window, 10)) {
      return reply.code(429).send(errorBody('RATE_LIMITED', 'Too many activation attempts. Try again later.'))
    }

    const codeDigest = invitationDigest(config.invitationLookupSecret, body.invitationCode.trim().toUpperCase())
    const invitation = await repository.findInvitationByDigest(codeDigest)
    if (!invitation) return reply.code(403).send(errorBody('INVALID_INVITATION', 'The invitation cannot be used.'))
    if (invitation.status !== 'active') return reply.code(403).send(errorBody('INVITATION_INACTIVE', 'The invitation cannot be used.'))
    if ((invitation.validFrom && current < invitation.validFrom) || (invitation.validUntil && current > invitation.validUntil)) {
      return reply.code(403).send(errorBody('INVITATION_EXPIRED', 'The invitation cannot be used.'))
    }
    const club = await repository.findClub(invitation.clubId)
    if (!clubIsActive(club, current)) return reply.code(403).send(errorBody('CLUB_LICENCE_INACTIVE', 'Club activation is unavailable.'))

    const refreshCredential = randomToken()
    const credentialDigest = refreshDigest(config.refreshLookupSecret, refreshCredential)
    const result = await repository.createOrGetInstallation({
      id: randomUUID(), publicInstallationId: body.installationId, clubId: club.id,
      invitationId: invitation.id, now: current, appVersion: body.appVersion,
      platform: String(body.platform), refreshCredentialDigest: credentialDigest,
    })
    if (result.kind === 'limitReached') {
      return reply.code(403).send(errorBody('ACTIVATION_LIMIT_REACHED', 'Club activation is unavailable.'))
    }
    if (result.kind === 'existing') {
      await repository.rotateInstallationCredential(result.installation.id, credentialDigest, body.appVersion, String(body.platform), current)
    }
    if (result.installation.status !== 'active') {
      return reply.code(403).send(errorBody('CLUB_LICENCE_INACTIVE', 'Club activation is unavailable.'))
    }
    const envelope = await issueEntitlement(repository, config, club, result.installation, invitation.policyVersion, current)
    return reply.code(201).send({ entitlement: envelope, refreshCredential })
  })

  app.post('/v1/entitlements/refresh', async (request, reply) => {
    const body = objectBody(request.body)
    if (!body || typeof body.refreshCredential !== 'string' || !validInstallationId(body.installationId) || !validVersion(body.appVersion)) {
      return reply.code(400).send(errorBody('MALFORMED_REQUEST', 'The refresh request is invalid.'))
    }
    const digest = refreshDigest(config.refreshLookupSecret, body.refreshCredential)
    const installation = await repository.findInstallationForRefresh(body.installationId, digest)
    if (!installation || installation.status !== 'active') {
      return reply.code(403).send(errorBody('INVALID_ENTITLEMENT', 'The entitlement cannot be refreshed.'))
    }
    const current = now()
    const club = await repository.findClub(installation.clubId)
    if (!clubIsActive(club, current)) {
      return reply.code(403).send(errorBody('CLUB_LICENCE_INACTIVE', 'The entitlement cannot be refreshed.'))
    }
    const envelope = await issueEntitlement(repository, config, club, installation, 1, current)
    await repository.recordRefresh(installation.id, body.appVersion, current)
    return { entitlement: envelope }
  })

  app.setNotFoundHandler(async (_request, reply) => reply.code(404).send(errorBody('NOT_FOUND', 'Route not found.')))
  app.setErrorHandler(async (error, request, reply) => {
    request.log.error({ kind: error instanceof Error ? error.name : 'unknown' }, 'licensing_request_failed')
    return reply.code(503).send(errorBody('TEMPORARY_SERVER_ERROR', 'The licensing service is temporarily unavailable.'))
  })
  return app
}

async function issueEntitlement(repository: LicensingRepository, config: LicensingConfig, club: Club, installation: Installation, policyVersion: number, now: Date) {
  const perpetual = club.licenceType === 'perpetual' && club.perpetualAccess
  const enabledFeatures = club.updatesUntil && now > club.updatesUntil
    ? club.enabledFeatures.filter((feature) => feature !== 'coursePackUpdates') : club.enabledFeatures
  const payload: EntitlementPayload = {
    schemaVersion: 1, entitlementId: randomUUID(), clubId: club.id,
    permittedPackIds: club.permittedPackIds, installationId: installation.publicInstallationId,
    entitlementType: perpetual ? 'perpetual' : 'term', enabledFeatures,
    issuedAt: iso(now), refreshAfter: iso(addDays(now, config.currentDays)),
    expiresAt: perpetual ? null : iso(addDays(now, config.expiryDays)),
    graceUntil: perpetual ? null : iso(addDays(now, config.graceDays)),
    perpetualAccess: perpetual, keyId: config.signingKeyId,
  }
  const envelope = signEntitlement(payload, config.signingPrivateKeyPkcs8)
  const record: EntitlementRecord = {
    id: payload.entitlementId, installationId: installation.id, clubId: club.id, policyVersion,
    issuedAt: now, refreshAfter: addDays(now, config.currentDays),
    expiresAt: perpetual ? null : addDays(now, config.expiryDays),
    graceUntil: perpetual ? null : addDays(now, config.graceDays), signingKeyId: config.signingKeyId,
    status: 'active', replacedById: null, revokedAt: null, createdAt: now,
  }
  await repository.saveEntitlement(record)
  return envelope
}

function objectBody(value: unknown): JsonObject | null { return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as JsonObject : null }
function errorBody(code: string, message: string) { return { error: { code, message } } }
function iso(date: Date): string { return date.toISOString().replace(/\.\d{3}Z$/, 'Z') }
function addDays(date: Date, days: number): Date { return new Date(date.getTime() + days * 86_400_000) }
function validInstallationId(value: unknown): value is string { return typeof value === 'string' && /^[A-Za-z0-9_-]{20,128}$/.test(value) }
function validVersion(value: unknown): value is string { return typeof value === 'string' && /^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$/.test(value) }
function versionBelow(value: string, minimum: string): boolean {
  const left = value.split(/[+-]/)[0].split('.').map(Number); const right = minimum.split(/[+-]/)[0].split('.').map(Number)
  for (let index = 0; index < 3; index++) if (left[index] !== right[index]) return left[index] < right[index]
  return false
}
function clubIsActive(club: Club | null, now: Date): club is Club {
  return Boolean(club && club.status === 'active' && (!club.licenceStartsAt || now >= club.licenceStartsAt)
    && (club.licenceType === 'perpetual' || !club.licenceEndsAt || now <= club.licenceEndsAt))
}
