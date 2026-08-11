export interface LicensingConfig {
  mongoUrl: string
  mongoDatabase: string
  invitationLookupSecret: string
  refreshLookupSecret: string
  signingPrivateKeyPkcs8: string
  signingKeyId: string
  currentDays: number
  expiryDays: number
  graceDays: number
  minimumAppVersion: string
  port: number
  host: string
  trustProxy: boolean
  auth0Domain?: string
  auth0Audience?: string
  adminWebOrigins: string[]
}

function required(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Missing required environment variable: ${name}`)
  return value
}

function positiveInteger(name: string, fallback: number): number {
  const value = Number(process.env[name] ?? fallback)
  if (!Number.isInteger(value) || value <= 0) throw new Error(`${name} must be a positive integer`)
  return value
}

export function loadConfig(): LicensingConfig {
  return {
    mongoUrl: required('MONGO_URL'),
    mongoDatabase: process.env.MONGO_DATABASE ?? 'syc_licensing',
    invitationLookupSecret: required('INVITATION_LOOKUP_SECRET'),
    refreshLookupSecret: required('REFRESH_LOOKUP_SECRET'),
    signingPrivateKeyPkcs8: required('ED25519_PRIVATE_KEY_PKCS8'),
    signingKeyId: required('SIGNING_KEY_ID'),
    currentDays: positiveInteger('DEFAULT_CURRENT_DAYS', 14),
    expiryDays: positiveInteger('DEFAULT_EXPIRY_DAYS', 30),
    graceDays: positiveInteger('DEFAULT_GRACE_DAYS', 60),
    minimumAppVersion: process.env.MINIMUM_APP_VERSION ?? '1.0.0',
    port: positiveInteger('PORT', 3000),
    host: process.env.HOST ?? '0.0.0.0',
    trustProxy: process.env.TRUST_PROXY !== 'false',
    auth0Domain: process.env.AUTH0_DOMAIN,
    auth0Audience: process.env.AUTH0_AUDIENCE,
    adminWebOrigins: (process.env.ADMIN_WEB_ORIGINS ?? 'http://localhost:5173').split(',').map((value) => value.trim()).filter(Boolean),
  }
}
