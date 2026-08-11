import { createRemoteJWKSet, jwtVerify } from 'jose'
import type { FastifyRequest } from 'fastify'

export type AdminRole = 'owner' | 'publisher' | 'editor'
export type AdminPrincipal = { subject: string; email?: string }
export type ClubAdminMembership = { subject: string; clubId: string; role: AdminRole; status: 'active' | 'inactive'; createdAt: Date; updatedAt: Date }
export type CoursePackDraft = { clubId: string; revision: number; payload: Record<string, unknown>; updatedBy: string; updatedAt: Date }
export type PublishedCoursePack = { id: string; clubId: string; version: string; payload: Record<string, unknown>; publishedBy: string; publishedAt: Date }

export interface AdminRepository {
  findAdminMembership(subject: string): Promise<ClubAdminMembership | null>
  getCoursePackDraft(clubId: string): Promise<CoursePackDraft | null>
  saveCoursePackDraft(clubId: string, payload: Record<string, unknown>, subject: string, expectedRevision: number | null, now: Date): Promise<CoursePackDraft | 'conflict'>
  publishCoursePack(clubId: string, subject: string, version: string, now: Date): Promise<PublishedCoursePack | null>
}

export type AdminAuthenticator = (request: FastifyRequest) => Promise<AdminPrincipal>

export function createAuth0Authenticator(domain: string, audience: string): AdminAuthenticator {
  const issuer = `https://${domain.replace(/^https?:\/\//, '').replace(/\/$/, '')}/`
  const jwks = createRemoteJWKSet(new URL(`${issuer}.well-known/jwks.json`))
  return async (request) => {
    const header = request.headers.authorization
    if (!header?.startsWith('Bearer ')) throw new Error('missing_token')
    const { payload } = await jwtVerify(header.slice(7), jwks, { issuer, audience, algorithms: ['RS256'] })
    if (!payload.sub) throw new Error('missing_subject')
    return { subject: payload.sub, email: typeof payload.email === 'string' ? payload.email : undefined }
  }
}
