import { createHmac, createPrivateKey, randomBytes, sign } from 'node:crypto'
import type { EntitlementEnvelope, EntitlementPayload } from './models.js'

export function base64url(bytes: Uint8Array): string { return Buffer.from(bytes).toString('base64url') }

function hmac(secret: string, value: string): string {
  return createHmac('sha256', secret).update(value, 'utf8').digest('base64url')
}

export function invitationDigest(secret: string, normalizedCode: string): string {
  return hmac(secret, `invitation:v1:${normalizedCode}`)
}

export function refreshDigest(secret: string, credential: string): string {
  return hmac(secret, `refresh:v1:${credential}`)
}

// The exact JSON UTF-8 bytes returned in envelope.payload are signed. Verifiers never re-encode it.
export function canonicalPayload(payload: EntitlementPayload): Buffer {
  const ordered = {
    schemaVersion: payload.schemaVersion,
    entitlementId: payload.entitlementId,
    clubId: payload.clubId,
    permittedPackIds: [...payload.permittedPackIds].sort(),
    installationId: payload.installationId,
    entitlementType: payload.entitlementType,
    enabledFeatures: [...payload.enabledFeatures].sort(),
    issuedAt: payload.issuedAt,
    refreshAfter: payload.refreshAfter,
    expiresAt: payload.expiresAt,
    graceUntil: payload.graceUntil,
    perpetualAccess: payload.perpetualAccess,
    keyId: payload.keyId,
  }
  return Buffer.from(JSON.stringify(ordered), 'utf8')
}

export function signEntitlement(payload: EntitlementPayload, pkcs8Base64: string): EntitlementEnvelope {
  const bytes = canonicalPayload(payload)
  const privateKey = createPrivateKey({ key: Buffer.from(pkcs8Base64, 'base64'), format: 'der', type: 'pkcs8' })
  return { payload: bytes.toString('base64url'), signature: sign(null, bytes, privateKey).toString('base64url') }
}

export function randomToken(byteCount = 32): string { return randomBytes(byteCount).toString('base64url') }
