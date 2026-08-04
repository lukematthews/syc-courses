import { loadConfig } from '../src/config.js'
import { MongoLicensingRepository } from '../src/mongoRepository.js'

const config = loadConfig()
const repository = await MongoLicensingRepository.connect(config.mongoUrl, config.mongoDatabase)
try { await repository.ensureIndexes(); console.log('MongoDB licensing indexes are ready.') }
finally { await repository.close() }
