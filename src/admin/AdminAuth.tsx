import { Auth0Provider, useAuth0 } from '@auth0/auth0-react'
import type { PropsWithChildren } from 'react'
import { AdminIdentityContext } from './AdminIdentity'

const domain = import.meta.env.VITE_AUTH0_DOMAIN as string | undefined
const clientId = import.meta.env.VITE_AUTH0_CLIENT_ID as string | undefined
const audience = import.meta.env.VITE_AUTH0_AUDIENCE as string | undefined
const devBypass = import.meta.env.DEV && import.meta.env.VITE_ADMIN_DEV_BYPASS !== 'false'

export function AdminAuthProvider({ children }: PropsWithChildren) {
  if (!domain || !clientId) return <AdminIdentityContext.Provider value={{ name: 'Local administrator', email: 'developer@localhost', isDevelopment: true }}>{children}</AdminIdentityContext.Provider>
  return (
    <Auth0Provider
      domain={domain}
      clientId={clientId}
      authorizationParams={{ redirect_uri: `${window.location.origin}/admin`, audience }}
      cacheLocation="memory"
    >
      <IdentityBridge>{children}</IdentityBridge>
    </Auth0Provider>
  )
}

function IdentityBridge({ children }: PropsWithChildren) {
  const { user, logout, getAccessTokenSilently } = useAuth0()
  return <AdminIdentityContext.Provider value={{ name: user?.name ?? user?.email ?? 'Administrator', email: user?.email ?? '', isDevelopment: false, logout: () => logout({ logoutParams: { returnTo: window.location.origin } }), getAccessToken: getAccessTokenSilently }}>{children}</AdminIdentityContext.Provider>
}

export function AdminAuthGate({ children }: PropsWithChildren) {
  if (!domain || !clientId) {
    if (devBypass) return <>{children}</>
    return (
      <main className="admin-auth-page">
        <section className="admin-auth-panel">
          <img src="/app-icon.png" alt="" />
          <h1>Club administration unavailable</h1>
          <p>Auth0 has not been configured for this deployment.</p>
        </section>
      </main>
    )
  }
  return <ConfiguredGate>{children}</ConfiguredGate>
}

function ConfiguredGate({ children }: PropsWithChildren) {
  const { isAuthenticated, isLoading, loginWithRedirect } = useAuth0()
  if (isLoading) return <main className="admin-auth-page"><p>Checking administrator access…</p></main>
  if (!isAuthenticated) {
    return (
      <main className="admin-auth-page">
        <section className="admin-auth-panel">
          <img src="/app-icon.png" alt="" />
          <h1>Club administration</h1>
          <p>Sign in to maintain your club’s course pack.</p>
          <button className="admin-primary-button" onClick={() => loginWithRedirect()}>Sign in with Auth0</button>
        </section>
      </main>
    )
  }
  return <>{children}</>
}
