import { randomUUID } from 'node:crypto'
import Fastify, { type FastifyInstance } from 'fastify'
import cors from '@fastify/cors'
import type { LicensingConfig } from './config.js'
import { invitationDigest, randomToken, refreshDigest, signEntitlement } from './crypto.js'
import type { Club, EntitlementPayload, EntitlementRecord, Installation } from './models.js'
import type { LicensingRepository } from './repository.js'
import type { AdminAuthenticator, AdminRepository, AdminRole } from './admin.js'

type JsonObject = Record<string, unknown>
export interface AppDependencies {
  repository: LicensingRepository
  config: LicensingConfig
  now?: () => Date
  adminRepository?: AdminRepository
  adminAuthenticator?: AdminAuthenticator
}

class PrivacyLogController extends Fastify.LogController {
  constructor() { super({ disableRequestLogging: true }) }
}

export function buildApp({ repository, config, now = () => new Date(), adminRepository, adminAuthenticator }: AppDependencies): FastifyInstance {
  const app = Fastify({
    trustProxy: config.trustProxy,
    bodyLimit: 16 * 1024,
    logController: new PrivacyLogController(),
    logger: process.env.NODE_ENV === 'test' ? false : {
      level: process.env.LOG_LEVEL ?? 'info',
      redact: ['req.headers.authorization', 'req.body', 'res.body'],
    },
  })

  if (adminRepository && adminAuthenticator) {
    void app.register(cors, { origin: config.adminWebOrigins, methods: ['GET', 'PUT', 'POST', 'OPTIONS'] })
  }

  app.addHook('onSend', async (_request, reply, payload) => {
    reply.header('cache-control', 'no-store')
    reply.header('x-content-type-options', 'nosniff')
    return payload
  })

  app.get('/v1/health', async (_request, reply) => {
    try { await repository.ping(); return { status: 'ok', schemaVersion: 1 } }
    catch { return reply.code(503).send(errorBody('TEMPORARY_SERVER_ERROR', 'The licensing service is temporarily unavailable.')) }
  })

  if (adminRepository && adminAuthenticator) {
    const access = async (request: Parameters<AdminAuthenticator>[0], roles: AdminRole[]) => {
      const principal = await adminAuthenticator(request)
      const membership = await adminRepository.findAdminMembership(principal.subject)
      if (!membership || !roles.includes(membership.role)) throw new Error('forbidden')
      return { principal, membership }
    }

    app.get('/v1/admin/course-pack', async (request, reply) => {
      try {
        const { membership } = await access(request, ['owner', 'publisher', 'editor'])
        const draft = await adminRepository.getCoursePackDraft(membership.clubId)
        if (!draft) return reply.code(404).send(errorBody('COURSE_PACK_NOT_INITIALISED', 'No editable course pack has been created for this club.'))
        return { clubId: membership.clubId, role: membership.role, revision: draft.revision, pack: draft.payload }
      } catch { return reply.code(403).send(errorBody('ADMIN_ACCESS_DENIED', 'Administrator access is unavailable.')) }
    })

    app.put('/v1/admin/course-pack', { bodyLimit: 12 * 1024 * 1024 }, async (request, reply) => {
      try {
        const { principal, membership } = await access(request, ['owner', 'publisher', 'editor'])
        const body = objectBody(request.body); const pack = body && objectBody(body.pack)
        if (!pack || (body.revision !== null && body.revision !== undefined && !Number.isInteger(body.revision))) return reply.code(400).send(errorBody('MALFORMED_REQUEST', 'The course pack draft is invalid.'))
        const saved = await adminRepository.saveCoursePackDraft(membership.clubId, pack, principal.subject, typeof body.revision === 'number' ? body.revision : null, now())
        if (saved === 'conflict') return reply.code(409).send(errorBody('EDIT_CONFLICT', 'The course pack was changed by another administrator. Reload before saving.'))
        return { clubId: membership.clubId, role: membership.role, revision: saved.revision, pack: saved.payload }
      } catch { return reply.code(403).send(errorBody('ADMIN_ACCESS_DENIED', 'Administrator access is unavailable.')) }
    })

    app.post('/v1/admin/course-pack/publish', async (request, reply) => {
      try {
        const { principal, membership } = await access(request, ['owner', 'publisher'])
        const body = objectBody(request.body)
        if (!body || typeof body.version !== 'string' || !/^\d{4}\.\d{2}\.\d{2}(?:\.\d+)?$/.test(body.version)) return reply.code(400).send(errorBody('MALFORMED_REQUEST', 'The published version is invalid.'))
        const published = await adminRepository.publishCoursePack(membership.clubId, principal.subject, body.version, now())
        if (!published) return reply.code(409).send(errorBody('COURSE_PACK_NOT_INITIALISED', 'Save the course pack before publishing.'))
        return reply.code(201).send({ id: published.id, clubId: published.clubId, version: published.version, publishedAt: published.publishedAt })
      } catch { return reply.code(403).send(errorBody('ADMIN_ACCESS_DENIED', 'Publishing access is unavailable.')) }
    })
  }

  app.post('/v1/activations', async (request, reply) => {
    const body = objectBody(request.body)
    if (!body || typeof body.invitationCode !== 'string' || !validInstallationId(body.installationId)
      || !validVersion(body.appVersion) || !['ios', 'macos', 'android'].includes(String(body.platform))) {
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
