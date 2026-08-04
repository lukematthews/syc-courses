import type { Club, EntitlementRecord, Installation, Invitation } from './models.js'

export type InstallationResult =
  | { kind: 'created'; installation: Installation }
  | { kind: 'existing'; installation: Installation }
  | { kind: 'limitReached' }

export interface CreateInstallationInput {
  id: string
  publicInstallationId: string
  clubId: string
  invitationId: string
  now: Date
  appVersion: string
  platform: string
  refreshCredentialDigest: string
}

export interface LicensingRepository {
  ensureIndexes(): Promise<void>
  ping(): Promise<void>
  close(): Promise<void>
  consumeRateLimit(subjectDigest: string, windowStartedAt: Date, limit: number): Promise<boolean>
  findInvitationByDigest(codeDigest: string): Promise<Invitation | null>
  findClub(id: string): Promise<Club | null>
  createOrGetInstallation(input: CreateInstallationInput): Promise<InstallationResult>
  rotateInstallationCredential(id: string, digest: string, appVersion: string, platform: string, now: Date): Promise<void>
  findInstallationForRefresh(publicInstallationId: string, refreshCredentialDigest: string): Promise<Installation | null>
  recordRefresh(id: string, appVersion: string, now: Date): Promise<void>
  saveEntitlement(record: EntitlementRecord): Promise<void>
}
