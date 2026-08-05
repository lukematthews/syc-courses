# Club licensing operations guide

This guide organises licensing work by business task. It is for the person operating the licensing
service, not for club members. Member instructions are in
[`CLUB_MEMBER_ACTIVATION_GUIDE.md`](CLUB_MEMBER_ACTIVATION_GUIDE.md).

The current administration tool is intentionally small and command-line based. Commands operate on
the MongoDB selected by `MONGO_URL` and `MONGO_DATABASE`. Never load production connection values
until the production Railway service, backups, access controls, and monitoring have been reviewed.

## Business-level overview

| Business task | What changes | Existing members affected? |
| --- | --- | --- |
| Add a new yacht club | Creates its licence, packs, and service features | No |
| Invite club members | Creates one replaceable, time-limited invitation | No |
| Replace a leaked invitation | Stops new use of the old code and issues a new one | Existing activated installations continue |
| Pause new club activation | Disables an invitation | Existing activated installations continue |
| Suspend a club licence | Prevents activation and future refresh | Cached access follows its signed expiry policy; perpetual rights need contractual review |
| Disable one installation | Prevents that installation refreshing | Other installations are unaffected |
| Review adoption | Shows aggregate installation counts | No personal/member reporting is available |
| End update services | Removes update eligibility from newly issued entitlements after the configured date | Bundled/downloaded reference data remains available |

## Before administering clubs

From the repository root:

```bash
cd licensing-server
npm install
npm run check
npm test
npm run build
```

For local work, create an uncommitted `.env` or export the MongoDB URL, signing key and two
independent HMAC secrets. Create the MongoDB indexes with:

```bash
npm run db:indexes
```

Never paste secrets into tickets, chat, shell history shared with others, source control, or routine
logs. Never use the retired `SYC-TRIAL-26` code.

For the live Railway development service, prefer running administration commands inside the API
container. Install and authenticate the Railway CLI, link it to the project, then open a shell:

```bash
railway login
railway link
railway ssh --service YOUR_LICENSING_SERVICE
```

The deployed shell already has `MONGO_URL`, `MONGO_DATABASE`, and
`INVITATION_LOOKUP_SECRET`. Do not paste their values into the SSH session. Railway private service
references are usable from the deployed container, while the MongoDB service does not need a public
application endpoint.

## Live development example: three-year SYC term

This example creates a three-calendar-year term beginning at midnight Melbourne time on 5 August
2026 and ending at midnight Melbourne time on 5 August 2029. Both dates fall in AEST (UTC+10), so
the commands use 14:00 UTC on the preceding calendar day. The licence permits the bundled SYC
2025–2028 pack and includes the course-pack update service for the same term. Extending access
beyond that pack's underlying source period is a licensing decision; it does not make the course
information current beyond its stated source dates.

### 1. Confirm the live service

```bash
curl -s https://syc-courses-production.up.railway.app/v1/health
echo
```

Continue only when the response is:

```json
{"status":"ok","schemaVersion":1}
```

### 2. Open a Railway shell in the licensing API service

From the local repository:

```bash
cd licensing-server
railway login
railway link
railway ssh --service YOUR_LICENSING_SERVICE
```

Replace `YOUR_LICENSING_SERVICE` with the API service name shown on the Railway project canvas, not
the MongoDB service name.

### 3. Create the SYC term licence

Run this inside the Railway shell:

```bash
node scripts/admin.mjs create-club \
  --id sandringham-yacht-club \
  --name 'Sandringham Yacht Club' \
  --licence-type term \
  --starts-at 2026-08-04T14:00:00Z \
  --ends-at 2029-08-04T14:00:00Z \
  --updates-until 2029-08-04T14:00:00Z \
  --packs sandringham-yacht-club-2025-2028 \
  --features coursePackUpdates
```

Expected confirmation:

```text
Created club sandringham-yacht-club.
```

Do not run the command twice. The stable club ID is unique, so a second attempt should fail rather
than silently replace the existing commercial record.

### 4. Generate the development invitation code

Still inside the same Railway shell, run:

```bash
node scripts/admin.mjs create-invitation \
  --environment development \
  --club sandringham-yacht-club \
  --valid-from 2026-08-04T14:00:00Z \
  --valid-until 2029-08-04T14:00:00Z \
  --limit 2000
```

The command generates a random code rather than accepting an operator-chosen universal code. Its
output has this form:

```text
Invitation ID: <generated UUID>
DISPLAY ONCE — distribute securely; the code cannot be retrieved later:
DEV-<generated random value>
```

Copy both the invitation ID and the exact `DEV-...` code immediately into the approved development
test record. The displayed `DEV-...` value is the invitation code entered in the iOS app. The
database stores only its keyed digest and final-character hint, so there is no command to display it
again. If it is lost, create a replacement invitation and disable the lost invitation by ID.

### 5. Confirm the invitation record

```bash
node scripts/admin.mjs list-invitations
```

Confirm that the row shows:

- `clubId` of `sandringham-yacht-club`;
- `status` of `active`;
- expiry on 5 August 2029;
- `activationCount` of `0`;
- `activationLimit` of `2000`.

Exit the Railway shell with `exit`. Test the captured invitation on a development device using the
Release-configured Railway endpoint and matching public signing key. After activation, reconnect
with Railway SSH and run `node scripts/admin.mjs counts`; the active installation count should have
increased.

For a real production invitation, repeat only the invitation step with
`--environment production --confirm-production yes`. Do not use that flag merely because the
development service happens to be reachable on the public internet.

## Add a new yacht club

### 1. Collect the commercial decisions

Record these before running a command:

- stable club ID, such as `brighton-yacht-club`;
- official display name;
- licence type: `term` or `perpetual`;
- term end date, if applicable;
- permitted course-pack IDs;
- enabled service features;
- date through which course-pack update service is included;
- invitation activation window and a generous abuse threshold.

Do not represent a perpetual App-use right as perpetual hosting, support, updates, or future
services. For SYC, confirm the applicable version and service boundary commercially and legally.

### 2. Check the course pack exists

The current iPhone app still bundles one course pack at build time. A licence can name a pack ID,
but this does not create or download that pack. Confirm the ID in the pack's `pack.json` and confirm
that the appropriate app variant can be built before onboarding the club.

### 3. Create a term club

Local example:

```bash
node scripts/admin.mjs create-club \
  --id brighton-yacht-club \
  --name 'Brighton Yacht Club' \
  --licence-type term \
  --ends-at 2027-06-30T14:00:00Z \
  --updates-until 2027-06-30T14:00:00Z \
  --packs brighton-yacht-club-2026-2027 \
  --features coursePackUpdates
```

Use UTC timestamps. For multiple pack IDs or features, supply comma-separated values without
spaces.

### 4. Create a perpetual club

```bash
node scripts/admin.mjs create-club \
  --id sandringham-yacht-club \
  --name 'Sandringham Yacht Club' \
  --licence-type perpetual \
  --updates-until 2027-06-30T14:00:00Z \
  --packs sandringham-yacht-club-2025-2028 \
  --features coursePackUpdates
```

The perpetual flag controls continuing use of the licensed App/content state. `updates-until`
controls update-service eligibility separately. A licensing-server outage does not expire a cached
perpetual entitlement.

### 5. Verify the result

Before distributing an invitation, inspect the MongoDB document through an authorised read-only
database connection. Confirm:

- club ID and name;
- `status = active`;
- correct licence type and dates;
- correct `perpetualAccess` value;
- correct pack IDs and features.

Treat correcting a wrong perpetual/term decision as a commercial change requiring explicit review,
not routine data cleanup.

## Invite members of a club

Create one generous, replaceable invitation for club distribution. Do not create one code per
member.

```bash
node scripts/admin.mjs create-invitation \
  --environment development \
  --club brighton-yacht-club \
  --valid-until 2027-06-30T14:00:00Z \
  --limit 2000
```

The generated development invitation is displayed once. Capture it into the club's approved secret
distribution process; the plaintext cannot be retrieved later. Do not put it in ordinary service
logs or source control.

For an approved production database, require explicit production confirmation:

```bash
node scripts/admin.mjs create-invitation \
  --environment production --confirm-production yes \
  --club brighton-yacht-club \
  --valid-until 2027-06-30T14:00:00Z \
  --limit 2000
```

The club can distribute it as:

- invitation text in a member-only notice;
- a QR code or link that carries the code into the app when deep-link support is added;
- a printed short code at the club.

The code only starts activation. It is not itself a licence; the server must approve the club,
window, threshold, installation, and app version before issuing a signed entitlement.

## Replace a leaked or over-shared invitation

1. Create a replacement invitation for the same club.
2. Test it on a fresh development installation.
3. Distribute the replacement through the club's approved channel.
4. Disable the old invitation by its MongoDB invitation ID:

```bash
node scripts/admin.mjs set-invitation-status \
  --id OLD_INVITATION_ID \
  --status inactive
```

5. Monitor aggregate activation volume and rate limiting.

The old code can no longer activate new installations. Already-authorised installations continue
to refresh using their independent opaque credentials unless the club or installation is disabled.

## Pause and resume new activations

Pause one invitation:

```bash
node scripts/admin.mjs set-invitation-status --id INVITATION_ID --status inactive
```

Resume it only if its activation window is still valid:

```bash
node scripts/admin.mjs set-invitation-status --id INVITATION_ID --status active
```

This is the preferred response to invitation leakage because it does not disrupt existing members.

## Suspend or resume an entire club

Suspend:

```bash
node scripts/admin.mjs set-club-status --id CLUB_ID --status inactive
```

Resume:

```bash
node scripts/admin.mjs set-club-status --id CLUB_ID --status active
```

Suspension prevents new activations and refreshes. It does not erase already-downloaded course
information, remotely alter an old released binary, or instantly invalidate cached entitlements.
Do not suspend a perpetual SYC entitlement merely to end hosting, maintenance, update, or support
services; those are separate controls and require the agreed commercial interpretation.

## Disable a single installation

Use this only for a genuine support or abuse case after resolving the random public installation ID:

```bash
node scripts/admin.mjs disable-installation \
  --installation-id 11111111-1111-4111-8111-111111111111
```

This prevents future refresh for that installation. It does not delete sailing data—the service
does not collect any—and it does not remotely delete cached course information. Record the business
reason and retention/deletion date without recording member identity.

## Review club adoption

```bash
node scripts/admin.mjs counts
```

Report only aggregated values such as active and disabled installation counts by club. Do not try
to infer member identity, households, boat ownership, location, or sailing behaviour. Installation
count is not the same as unique member count.

Useful operational signals include:

- activations per club per week;
- refresh success/failure rate;
- invitation rate-limit events;
- app versions still requesting refresh;
- disabled installation count.

## Handle common member support cases

| Member report | Operator action |
| --- | --- |
| “Invitation not recognised” | Confirm the club supplied the current code; do not reveal whether another guessed code exists |
| “Invitation expired/inactive” | Confirm the current club invitation and distribution date |
| “Too many attempts” | Ask the member to wait for the rate-limit window; investigate unusual aggregate volume |
| “Update the app first” | Direct the member to the supported App Store release |
| “Unable to contact licensing service” | Check the Railway API health and connectivity; cached valid access should remain |
| “Downloaded courses show an expiry warning” | Ask the member to connect and press Retry; do not promise the information is current |
| “I upgraded and now see Legacy access” | Explain that the bundled SYC snapshot remains available but future updates require modern club activation |
| “I reinstalled the app” | Supply the current club invitation; do not restore access with a static universal code |

Never ask for email, Apple ID, location, sailing history, contact lists, or advertising identifiers.

## Signing-key rotation and emergency recovery

Routine rotation requires a release sequence:

1. Generate a new signing key outside source control.
2. Assign a new `keyId`.
3. Ship an app containing both old and new public keys.
4. Wait for sufficient adoption.
5. Change the Railway signing variable and active `keyId`.
6. Keep the old public key until all supported old entitlements are outside policy.

If the private key may be compromised, stop signing, preserve evidence without exposing secrets,
rotate immediately, prepare an app trust-set update, and reissue entitlements. Do not treat a key
incident as permission to silently revoke SYC's cached perpetual right.

## Production checklist

Before the first real club is onboarded:

- the Railway API and MongoDB services are provisioned in the intended project;
- `MONGO_URL` is a private Railway reference variable and the database name is correct;
- required indexes exist and a backup/restore procedure is tested;
- signing, invitation HMAC, and refresh HMAC secrets are independent and protected;
- the Release app embeds only matching public keys and the production HTTPS endpoint;
- operator access to MongoDB and Railway deployment is restricted and auditable;
- routine logs have a 30-day-or-less retention policy;
- rate-limit cleanup and disabled-record retention are scheduled;
- health/error/volume monitoring is enabled without sensitive payload logging;
- invitation creation and handoff have a display-once secure process;
- the club's licence type, dates, packs, features, and update-service boundary are approved;
- simulator and physical-device activation, offline launch, retry, and expiry messaging are tested.

## Current limitations

- The CLI is safe local tooling, not a multi-user administration dashboard.
- Production provisioning and operator access remain manual Railway responsibilities.
- Runtime course-pack download/update is not implemented; packs remain bundled at build time.
- QR/deep-link handling is not implemented yet; QR codes can presently display the invitation text.
- The system intentionally cannot report individual member identity.
