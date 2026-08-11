import { createContext, useContext } from 'react'

export type AdminIdentityValue = {
  name: string
  email: string
  isDevelopment: boolean
  logout?: () => void
  getAccessToken?: () => Promise<string>
}

export const AdminIdentityContext = createContext<AdminIdentityValue>({
  name: 'Administrator', email: '', isDevelopment: false,
})

export function useAdminIdentity() { return useContext(AdminIdentityContext) }
