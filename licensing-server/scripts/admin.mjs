#!/usr/bin/env node
import { createHmac, generateKeyPairSync, randomBytes, randomUUID } from 'node:crypto'
import { MongoClient } from 'mongodb'

const [command, ...args] = process.argv.slice(2)
const value = (name, fallback) => { const index = args.indexOf(`--${name}`); return index >= 0 ? args[index + 1] : fallback }
const required = (name) => { const result = value(name); if (!result) throw new Error(`Missing --${name}`); return result }
const dateValue = (name, fallback = null) => {
  const raw = value(name)
  if (!raw) return fallback
  const result = new Date(raw)
  if (Number.isNaN(result.getTime())) throw new Error(`--${name} must be an ISO 8601 timestamp`)
  return result
}
const databaseUrl = process.env.MONGO_URL
const databaseName = process.env.MONGO_DATABASE ?? 'syc_licensing'

if (command === 'generate-development-key') {
  const { privateKey, publicKey } = generateKeyPairSync('ed25519')
  console.log('TEST/DEVELOPMENT USE ONLY. Store the private value immediately; it will not be saved.')
  console.log(`privatePkcs8Base64=${privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64')}`)
  console.log(`publicRawBase64=${publicKey.export({ type: 'spki', format: 'der' }).subarray(-32).toString('base64')}`)
  process.exit(0)
}

if (!databaseUrl) throw new Error('Set MONGO_URL through an uncommitted environment or Railway variable reference.')
const client = new MongoClient(databaseUrl, { appName: 'syc-licensing-admin' })
await client.connect()
const database = client.db(databaseName)

try {
  const now = new Date()
  if (command === 'create-club') {
    const licenceType = value('licence-type', 'term')
    if (!['term', 'perpetual'].includes(licenceType)) throw new Error('--licence-type must be term or perpetual')
    const club = {
      id: required('id'), name: required('name'), status: 'active', licenceType,
      licenceStartsAt: dateValue('starts-at', now),
      licenceEndsAt: dateValue('ends-at'),
      perpetualAccess: licenceType === 'perpetual',
      updatesUntil: dateValue('updates-until'),
      enabledFeatures: value('features', '').split(',').filter(Boolean),
      permittedPackIds: required('packs').split(',').filter(Boolean), createdAt: now, updatedAt: now,
    }
    await database.collection('clubs').insertOne(club)
    console.log(`Created club ${club.id}.`)
  } else if (command === 'create-invitation') {
    const secret = process.env.INVITATION_LOOKUP_SECRET
    if (!secret) throw new Error('Set INVITATION_LOOKUP_SECRET without printing it.')
    const environment = value('environment', 'development')
    if (!['development', 'production'].includes(environment)) throw new Error('--environment must be development or production')
    if (environment === 'production' && value('confirm-production') !== 'yes') throw new Error('Production invitation creation requires --confirm-production yes')
    const prefix = environment === 'production' ? 'CLUB' : 'DEV'
    const code = `${prefix}-${randomBytes(9).toString('base64url').toUpperCase()}`
    const id = randomUUID()
    const codeDigest = createHmac('sha256', secret).update(`invitation:v1:${code}`).digest('base64url')
    await database.collection('invitations').insertOne({
      id, clubId: required('club'), codeDigest, codeHint: `…${code.slice(-4)}`, status: 'active',
      validFrom: dateValue('valid-from', now),
      validUntil: dateValue('valid-until'),
      activationLimit: value('limit') ? positiveInteger('limit') : null, activationCount: 0,
      policyVersion: 1, createdAt: now, updatedAt: now,
    })
    console.log(`Invitation ID: ${id}`)
    console.log('DISPLAY ONCE — distribute securely; the code cannot be retrieved later:')
    console.log(code)
  } else if (command === 'set-invitation-status') {
    const status = required('status'); if (!['active', 'inactive'].includes(status)) throw new Error('--status must be active or inactive')
    await database.collection('invitations').updateOne({ id: required('id') }, { $set: { status, updatedAt: now } })
    console.log('Invitation status updated.')
  } else if (command === 'set-club-status') {
    const status = required('status'); if (!['active', 'inactive'].includes(status)) throw new Error('--status must be active or inactive')
    await database.collection('clubs').updateOne({ id: required('id') }, { $set: { status, updatedAt: now } })
    console.log('Club status updated.')
  } else if (command === 'grant-admin') {
    const role = value('role', 'editor')
    if (!['owner', 'publisher', 'editor'].includes(role)) throw new Error('--role must be owner, publisher or editor')
    const subject = required('subject'); const clubId = required('club')
    await database.collection('clubAdminMemberships').updateOne(
      { subject },
      { $set: { clubId, role, status: 'active', updatedAt: now }, $setOnInsert: { createdAt: now } },
      { upsert: true },
    )
    console.log(`Granted ${role} access to ${subject} for ${clubId}.`)
  } else if (command === 'revoke-admin') {
    await database.collection('clubAdminMemberships').updateOne(
      { subject: required('subject') }, { $set: { status: 'inactive', updatedAt: now } },
    )
    console.log('Administrator access revoked.')
  } else if (command === 'disable-installation') {
    await database.collection('installations').updateOne({ publicInstallationId: required('installation-id') }, { $set: { status: 'disabled', updatedAt: now } })
    console.log('Installation disabled.')
  } else if (command === 'counts') {
    const rows = await database.collection('installations').aggregate([
      { $group: { _id: { clubId: '$clubId', status: '$status' }, installations: { $sum: 1 } } },
      { $project: { _id: 0, clubId: '$_id.clubId', status: '$_id.status', installations: 1 } },
      { $sort: { clubId: 1, status: 1 } },
    ]).toArray()
    console.table(rows)
  } else if (command === 'list-invitations') {
    const rows = await database.collection('invitations').find({}, { projection: { _id: 0, id: 1, clubId: 1, codeHint: 1, status: 1, validUntil: 1, activationCount: 1, activationLimit: 1 } }).sort({ clubId: 1, createdAt: -1 }).toArray()
    console.table(rows)
  } else {
    throw new Error('Commands: generate-development-key, create-club, create-invitation, list-invitations, set-invitation-status, set-club-status, grant-admin, revoke-admin, disable-installation, counts')
  }
} finally { await client.close() }

function positiveInteger(name) {
  const result = Number(required(name))
  if (!Number.isSafeInteger(result) || result <= 0) throw new Error(`--${name} must be a positive integer`)
  return result
}
