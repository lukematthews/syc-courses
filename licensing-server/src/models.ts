export type ClubStatus = 'active' | 'inactive'
export type LicenceType = 'term' | 'perpetual'

export interface Club {
  id: string
  name: string
  status: ClubStatus
  licenceType: LicenceType
  licenceStartsAt: Date | null
  licenceEndsAt: Date | null
  perpetualAccess: boolean
  updatesUntil: Date | null
  enabledFeatures: string[]
  permittedPackIds: string[]
  createdAt: Date
  updatedAt: Date
}

export interface Invitation {
  id: string
  clubId: string
  codeDigest: string
  codeHint: string
  status: 'active' | 'inactive'
  validFrom: Date | null
  validUntil: Date | null
  activationLimit: number | null
  activationCount: number
  policyVersion: number
  createdAt: Date
  updatedAt: Date
}

export interface Installation {
  id: string
  publicInstallationId: string
  clubId: string
  invitationId: string
  firstActivatedAt: Date
  lastRefreshedAt: Date
  appVersion: string
  platform: string
  status: 'active' | 'disabled'
  refreshCredentialDigest: string
  createdAt: Date
  updatedAt: Date
}

export interface EntitlementRecord {
  id: string
  installationId: string
  clubId: string
  policyVersion: number
  issuedAt: Date
  refreshAfter: Date
  expiresAt: Date | null
  graceUntil: Date | null
  signingKeyId: string
  status: 'active' | 'replaced' | 'revoked'
  replacedById: string | null
  revokedAt: Date | null
  createdAt: Date
}

export interface EntitlementPayload {
  schemaVersion: 1
  entitlementId: string
  clubId: string
  permittedPackIds: string[]
  installationId: string
  entitlementType: LicenceType
  enabledFeatures: string[]
  issuedAt: string
  refreshAfter: string
  expiresAt: string | null
  graceUntil: string | null
  perpetualAccess: boolean
  keyId: string
}

export interface EntitlementEnvelope { payload: string; signature: string }
