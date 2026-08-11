import { buildApp } from './app.js'
import { loadConfig } from './config.js'
import { MongoLicensingRepository } from './mongoRepository.js'
import { createAuth0Authenticator } from './admin.js'

const config = loadConfig()
const repository = await MongoLicensingRepository.connect(config.mongoUrl, config.mongoDatabase)
await repository.ensureIndexes()
const adminAuthenticator = config.auth0Domain && config.auth0Audience
  ? createAuth0Authenticator(config.auth0Domain, config.auth0Audience) : undefined
const app = buildApp({
  repository,
  config,
  adminRepository: adminAuthenticator ? repository : undefined,
  adminAuthenticator,
})

async function shutdown(signal: string) {
  app.log.info({ signal }, 'licensing_server_shutdown')
  await app.close()
  await repository.close()
}

process.once('SIGTERM', () => { void shutdown('SIGTERM') })
process.once('SIGINT', () => { void shutdown('SIGINT') })

try { await app.listen({ port: config.port, host: config.host }) }
catch (error) {
  app.log.error({ kind: error instanceof Error ? error.name : 'unknown' }, 'licensing_server_start_failed')
  await repository.close()
  process.exitCode = 1
}
