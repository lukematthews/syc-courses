import type { AdminPack } from './types'

const baseUrl = (import.meta.env.VITE_ADMIN_API_URL as string | undefined)?.replace(/\/$/, '')
export const hasAdminApi = Boolean(baseUrl)

type DraftResponse = { revision: number; pack: AdminPack }

async function request(path: string, token: string, init?: RequestInit) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json', ...init?.headers },
  })
  if (!response.ok) {
    const payload = await response.json().catch(() => null) as { error?: { code?: string; message?: string } } | null
    const error = new Error(payload?.error?.message ?? `Administrator API returned ${response.status}`) as Error & { status?: number; code?: string }
    error.status = response.status; error.code = payload?.error?.code
    throw error
  }
  return response
}

export async function loadRemotePack(token: string): Promise<DraftResponse> {
  return (await request('/v1/admin/course-pack', token)).json() as Promise<DraftResponse>
}

export async function saveRemotePack(token: string, pack: AdminPack, revision: number | null): Promise<DraftResponse> {
  return (await request('/v1/admin/course-pack', token, { method: 'PUT', body: JSON.stringify({ revision, pack }) })).json() as Promise<DraftResponse>
}

export async function publishRemotePack(token: string, version: string) {
  return (await request('/v1/admin/course-pack/publish', token, { method: 'POST', body: JSON.stringify({ version }) })).json()
}
