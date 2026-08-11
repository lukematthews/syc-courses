# Railway licensing API

This directory is a standalone Node.js service for Railway. It uses Fastify, MongoDB, and the same
Ed25519 entitlement envelope verified by the iPhone app. The Vercel-hosted web/PWA is unchanged.

Business procedures are in [`../LICENSING_OPERATIONS_GUIDE.md`](../LICENSING_OPERATIONS_GUIDE.md),
and member instructions are in
[`../CLUB_MEMBER_ACTIVATION_GUIDE.md`](../CLUB_MEMBER_ACTIVATION_GUIDE.md).

## Local development

Requirements: Node.js 22+ and a local MongoDB 7+ instance. One Docker option is:

```bash
docker run --name syc-licensing-mongo -p 27017:27017 -d mongo:8
```

Create an uncommitted `.env` or export these variables in your shell:

```text
MONGO_URL=mongodb://127.0.0.1:27017
MONGO_DATABASE=syc_licensing_development
INVITATION_LOOKUP_SECRET=<independent random secret>
REFRESH_LOOKUP_SECRET=<independent random secret>
ED25519_PRIVATE_KEY_PKCS8=<development PKCS8 DER base64>
SIGNING_KEY_ID=development-2026-01
DEFAULT_CURRENT_DAYS=14
DEFAULT_EXPIRY_DAYS=30
DEFAULT_GRACE_DAYS=60
MINIMUM_APP_VERSION=1.0.0
PORT=8787
AUTH0_DOMAIN=<tenant>.au.auth0.com
AUTH0_AUDIENCE=https://api.syc-courses.example
ADMIN_WEB_ORIGINS=http://localhost:5173,https://courses.example
```

Generate a development-only key pair:

```bash
node scripts/admin.mjs generate-development-key
```

Then:

```bash
npm install
npm run check
npm test
npm run build
npm run db:indexes
npm run dev
```

The server listens on `0.0.0.0:$PORT`. The committed iOS Debug configuration uses
`http://127.0.0.1:8787`.

Create local development data:

```bash
node scripts/admin.mjs create-club \
  --id dev-sailing-club --name 'DEVELOPMENT Sailing Club' --licence-type term \
  --ends-at 2099-01-01T00:00:00Z --packs sandringham-yacht-club-2025-2028 \
  --features coursePackUpdates

node scripts/admin.mjs create-invitation \
  --environment development --club dev-sailing-club \
  --valid-until 2099-01-01T00:00:00Z --limit 1000

# Use the Auth0 user `sub` claim, not an email address.
node scripts/admin.mjs grant-admin \
  --subject 'auth0|USER_ID' --club dev-sailing-club --role owner
```

## Railway deployment

1. Create a Railway project and add the official MongoDB template.
2. Add this GitHub repository as a service and set its root directory to `licensing-server`.
3. Railway will use `railway.json`, run `npm run build`, start with `npm start`, and check
   `/v1/health`.
4. Set `MONGO_URL` as a Railway reference variable to the Mongo service connection value, and set
   `MONGO_DATABASE=syc_licensing`.
5. Add the remaining variables from the list above as protected Railway service variables. Use a
   production signing key and independent high-entropy HMAC secrets; never use test fixtures.
6. Deploy, generate a Railway public domain for the service, then confirm it returns
   `{"status":"ok","schemaVersion":1}` from `/v1/health`.
7. Put that Railway HTTPS endpoint (for example, `https://<service>.up.railway.app`), the signing
   key ID, and the public raw Ed25519 key into the iOS Release build.

This deploys only the licensing API to Railway. The existing SYC Courses website remains on Vercel;
no custom domain or Cloudflare DNS configuration is required for the licensing service.

The service creates required unique, lookup, aggregate, and TTL indexes during startup. A failed
index bootstrap prevents the service becoming healthy.

## Production administration

Run admin commands only from an authorised machine with production `MONGO_URL`, `MONGO_DATABASE`,
and (for invitation creation) `INVITATION_LOOKUP_SECRET` loaded from secure storage.

Production invitation creation requires two explicit flags:

```bash
node scripts/admin.mjs create-invitation \
  --environment production --confirm-production yes \
  --club CLUB_ID --valid-until 2027-06-30T14:00:00Z --limit 2000
```

The command prints the invitation ID and the new code once. MongoDB stores only its keyed digest and
redacted hint.

Other commands:

```bash
node scripts/admin.mjs list-invitations
node scripts/admin.mjs set-invitation-status --id INVITATION_ID --status inactive
node scripts/admin.mjs set-club-status --id CLUB_ID --status inactive
node scripts/admin.mjs grant-admin --subject 'auth0|USER_ID' --club CLUB_ID --role publisher
node scripts/admin.mjs revoke-admin --subject 'auth0|USER_ID'
node scripts/admin.mjs disable-installation --installation-id PUBLIC_RANDOM_ID
node scripts/admin.mjs counts
```

## MongoDB operational notes

- Collections additionally include `clubAdminMemberships`, `coursePackDrafts`, and
  immutable `publishedCoursePacks` for the administrator portal.
- Activation thresholds use an atomic counter reservation on the invitation document. This works
  without replica-set transactions and cannot exceed the configured limit; a process failure at the
  wrong instant may conservatively consume one slot.
- The rate-limit collection uses a TTL index and stores only a keyed network-subject digest.
- Published invitation and refresh secrets are never stored in plaintext.
- Railway MongoDB is operational infrastructure: configure volume backups, restoration testing,
  monitoring, and restricted access before onboarding a real club.
