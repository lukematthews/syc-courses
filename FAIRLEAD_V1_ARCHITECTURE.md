# Fairlead V1 architecture and implementation plan

Status: accepted working architecture. This document describes planned work only; no implementation is implied.

## Architectural summary

Fairlead V1 uses seven business concepts:

```text
External identity
       |
       +-- Membership -- Organisation
                              |
                              +-- OrganisationContent
                              |     +-- Marks
                              |     +-- Courses
                              |     +-- Shared Documents
                              |
                              +-- Event
                              |     +-- embedded Races
                              |     +-- shared Course references
                              |     +-- shared Document references
                              |     +-- embedded Event Courses
                              |     +-- embedded Event Documents
                              |     +-- embedded Notices
                              |
                              +-- EventPublication
                              +-- EntitlementGrant
                              +-- EventCreditTransaction
```

The product distinctions are:

```text
OrganisationContent = what the organisation knows
Event               = what the organisation is running
EventPublication    = exactly what competitors were told
Entitlements/Credits = whether the organisation may publish it
```

The central versioning decision is to keep editable content coarse and make an immutable `EventPublication` manifest the historical and offline-distribution boundary. V1 does not require separate `CourseRevision`, `MarkRevision`, or `DocumentRevision` collections.

Legacy device and course-pack licensing remains alongside this model during migration. It is not Fairlead's Organisation entitlement model.

## Resolved V1 decisions

### Event Course ownership

Use the same Course data shape in two unambiguous locations:

```text
OrganisationContent.courses[]
Event.eventCourses[]
```

- Organisation Courses are reusable library content.
- Event Courses exist only inside their Event.
- Events reference shared Organisation Courses by ID.
- An Event Course is promoted by copying it into `OrganisationContent` with a new Organisation Course ID.
- Organisation Courses do not contain `visibility` or `eventId` fields.

### Event Credit expiry

V1 Event Credits do not expire independently.

- Purchased and starter-bundle credits carry forward.
- Expired platform access prevents publishing but does not destroy unused credits.
- Restored credits are ordinary non-expiring credits.
- V1 requires no credit lots, allocation ordering, or reservation system.

Publication requires:

```text
active PLATFORM_ACCESS
and
(EVENT_PUBLISHING_UNLIMITED or usableCredits >= 1)
```

Usable credit balance is:

```text
GRANT + RESTORE + ADJUST - CONSUME
```

Expiring promotional credit lots may be added later if commercial evidence justifies the complexity.

### Publication numbering

`Event.latestPublicationId` is a convenience pointer only. Publication identity is protected by:

```text
unique (eventId, publicationNumber)
```

Publication and the Event pointer update occur in one MongoDB transaction. A unique initial-consumption constraint prevents concurrent or retried requests from charging twice.

## V1 domain model

### Organisation

```ts
type Organisation = {
  id: string
  name: string
  slug: string
  type: 'club' | 'class_association' | 'organising_authority' | 'other'
  status: 'active' | 'inactive'
  branding: {
    shortName?: string
    logoAssetId?: string
    primaryColour?: string
  }
  createdAt: Date
  updatedAt: Date
}
```

Organisation hierarchies and multi-club agreement structures are deferred.

### Membership

```ts
type Membership = {
  id: string
  identitySubject: string
  organisationId: string
  role: 'owner' | 'publisher' | 'editor'
  status: 'active' | 'inactive'
  createdAt: Date
  updatedAt: Date
}
```

Auth0 continues to authenticate administrators. Fairlead owns memberships and roles. The unique identity is `(identitySubject, organisationId)`, allowing a user to belong to multiple Organisations.

A configurable permission system is deferred. V1 maps the existing roles to named operations in application code.

### OrganisationContent

```ts
type OrganisationContent = {
  organisationId: string
  revision: number
  courseGroups: CourseGroup[]
  navigation: NavigationDefaults
  marks: Mark[]
  courses: Course[]
  sharedDocuments: SharedDocument[]
  updatedBy: string
  updatedAt: Date
}
```

This evolves the existing whole-course-pack draft. The integer revision provides optimistic concurrency. V1 deliberately avoids individual resource repositories and revision histories.

The following current `AdminPack` fields move out of the content aggregate:

- `members` to `memberships`;
- `notices` to Events;
- publication fields to `EventPublication`;
- frontend audit entries to an optional server activity log.

### Mark

```ts
type Mark = {
  id: string
  name: string
  aliases: string[]
  latitude: number
  longitude: number
  description?: string
  coordinatesStatus: string
}
```

The current Mark model is adequate for V1.

### Course

```ts
type Course = {
  id: string
  kind: 'fixed' | 'laid'
  groupId: string
  courseNumber: number
  route?: string
  passInstruction: string
  legs: CourseLeg[]
  totalDistanceNm?: number
  chartAssetId?: string
  chartAlt?: string
}

type CourseLeg = {
  id: string
  markId?: string
  displayName: string
  roundingSide: string
  officialBearing?: string
  officialDistance?: string
}
```

`markId` is authoritative when a leg uses a known fixed mark. `displayName` supports rendering, legacy imports, and instructions that do not resolve to coordinates. Advanced gates, lines, relative marks, metric provenance, and the complete future Course Designer step system are deferred.

Existing pack and Course IDs are retained as migration aliases, but new server IDs should not encode publication periods.

### SharedDocument

```ts
type SharedDocument = {
  id: string
  title: string
  category: 'COURSE_GUIDE' | 'SAILING_INSTRUCTIONS' | 'OTHER'
  assetId: string
  effectiveDate?: string
  revisionLabel?: string
  status: 'draft' | 'current' | 'withdrawn'
}
```

V1 imports the Fixed Course Guide and Standard Sailing Instructions as uploaded shared documents. Generated and hybrid Course Guides are deferred.

Replacing a document creates a new immutable asset and updates editable Organisation content. Existing Event publications retain the old asset ID and hash.

### Event

```ts
type Event = {
  id: string
  organisationId: string
  publicId: string
  name: string
  description?: string
  startsAt: Date
  endsAt: Date
  status: 'draft' | 'published' | 'archived'

  races: Race[]
  sharedCourseIds: string[]
  sharedDocumentIds: string[]
  eventCourses: Course[]
  eventDocuments: EventDocument[]
  notices: Notice[]

  firstPublishedAt?: Date
  latestPublicationId?: string
  revision: number
  createdBy: string
  updatedBy: string
  createdAt: Date
  updatedAt: Date
}
```

The Event revision provides optimistic editing concurrency and is not historical versioning.

### Race

```ts
type Race = {
  id: string
  name: string
  scheduledAt?: Date
  courseId?: string
  status?: 'scheduled' | 'completed' | 'abandoned'
}
```

Races remain embedded. A Course is optional and may resolve to a selected shared Course or an Event Course. A Race does not require a unique Course.

### EventDocument and Notice

```ts
type EventDocument = {
  id: string
  title: string
  category: 'EVENT_SI' | 'RESULTS' | 'OTHER'
  assetId: string
}
```

The existing structured Notice shape remains, with stronger Race applicability:

```ts
type Notice = {
  id: string
  noticeNumber: string
  title: string
  appliesToRaceIds: string[]
  appliesToText?: string
  issueDate: string
  summary: string
  warningSignals: string[]
  sections: NoticeSection[]
  issuerName: string
  issuerRole: string
  revision: number
  assetId?: string
}
```

`appliesToText` supports legacy import and cases that are not expressible as Race IDs.

### EventPublication

```ts
type EventPublication = {
  id: string
  eventId: string
  organisationId: string
  publicationNumber: number
  schemaVersion: 1
  manifest: EventManifest
  manifestHash: string
  publishedBy: string
  publishedAt: Date
}
```

The immutable manifest contains copied, resolved public content:

```ts
type EventManifest = {
  publicId: string
  organisation: PublicOrganisationSnapshot
  event: PublicEventSnapshot
  races: Race[]
  marks: Mark[]
  courses: Course[]
  documents: PublishedDocumentReference[]
  notices: PublishedNotice[]
  generatedAt: string
}
```

Documents and other binaries are pinned by immutable asset metadata:

```ts
type PublishedDocumentReference = {
  id: string
  title: string
  category: string
  downloadUrl: string
  sha256: string
  sizeBytes: number
  mimeType: string
}
```

Shared Courses and required Marks are copied into the manifest. Binaries are referenced by immutable object keys and hashes.

### EntitlementGrant

```ts
type EntitlementGrant = {
  id: string
  organisationId: string
  capability: 'PLATFORM_ACCESS' | 'EVENT_PUBLISHING_UNLIMITED' | 'SUPPORT'
  source: 'PURCHASE' | 'STARTER_BUNDLE' | 'FOUNDING_PARTNER' | 'PROMOTION' | 'MANUAL' | 'MIGRATION'
  startsAt: Date
  expiresAt: Date | null
  status: 'active' | 'revoked'
  externalReference?: string
  note?: string
  createdBy: string
  createdAt: Date
}
```

`expiresAt: null` means lifetime. Unlimited Event publishing is a capability, not a large credit quantity. Prices and billing-provider plan IDs do not belong here.

### EventCreditTransaction

```ts
type EventCreditTransaction = {
  id: string
  organisationId: string
  type: 'GRANT' | 'CONSUME' | 'RESTORE' | 'ADJUST'
  quantity: number
  eventId?: string
  source: 'PURCHASE' | 'STARTER_BUNDLE' | 'PROMOTION' | 'MANUAL' | 'MIGRATION' | 'REFUND'
  idempotencyKey: string
  relatedTransactionId?: string
  note?: string
  createdBy: string
  createdAt: Date
}
```

Quantities are positive; transaction type determines balance direction. Transactions do not expire in V1.

## Persistence plan

### Retain unchanged for legacy licensing

```text
clubs
invitations
installations
entitlements
activationRateLimits
```

Do not rename these in place. Their device-, pack-, and signature-bound semantics are materially different from Fairlead Organisation entitlements.

### Migrate existing admin collections

`clubAdminMemberships` migrates to `memberships`:

```text
subject -> identitySubject
clubId  -> organisationId
role    -> role
status  -> status
```

Retain the original collection until migration is verified.

`coursePackDrafts` migrates to `organisationContent`. Import Marks, Courses, groups, and navigation defaults; remove embedded members, notices, audit, and publication state.

Retain `publishedCoursePacks` as legacy publication/import history. Do not automatically treat a published pack as an Event.

### Add domain collections

```text
organisations
memberships
organisationContent
events
eventPublications
entitlementGrants
eventCreditTransactions
```

### Add object-storage metadata

Add an infrastructure `assets` collection:

```ts
type AssetRecord = {
  id: string
  organisationId: string
  objectKey: string
  originalFileName: string
  mimeType: string
  sizeBytes: number
  sha256: string
  createdBy: string
  createdAt: Date
}
```

Object keys are immutable. Replacing a file creates a new object and asset record. The `assets` collection is infrastructure metadata, not an additional business aggregate.

## MongoDB indexes

### Organisations

```text
unique { id: 1 }
unique { slug: 1 }
       { status: 1 }
```

### Memberships

```text
unique { id: 1 }
unique { identitySubject: 1, organisationId: 1 }
       { organisationId: 1, status: 1 }
       { identitySubject: 1, status: 1 }
```

Remove the current unique-subject index only after migration succeeds.

### Organisation content

```text
unique { organisationId: 1 }
```

### Events

```text
unique { id: 1 }
unique { publicId: 1 }
       { organisationId: 1, status: 1, startsAt: -1 }
```

### Event publications

```text
unique { id: 1 }
unique { eventId: 1, publicationNumber: 1 }
       { organisationId: 1, publishedAt: -1 }
```

### Entitlement grants

```text
unique { id: 1 }
       { organisationId: 1, capability: 1, status: 1, startsAt: 1, expiresAt: 1 }
sparse { externalReference: 1 }
```

### Event Credit transactions

```text
unique { id: 1 }
unique { organisationId: 1, idempotencyKey: 1 }
       { organisationId: 1, createdAt: 1 }
       { eventId: 1, type: 1 }
```

Add a partial unique constraint for one `CONSUME` transaction per Organisation/Event in V1. If later rules permit multiple consumption purposes, replace this with a specific `purpose: INITIAL_PUBLICATION` constraint.

### Assets

```text
unique { id: 1 }
unique { objectKey: 1 }
       { organisationId: 1, createdAt: -1 }
       { sha256: 1 }
```

SHA-256 is not globally unique because Organisations may independently upload identical files.

## API plan

### Organisation and identity

```http
GET /v1/admin/organisations
GET /v1/admin/organisations/:organisationId
```

The list endpoint returns all active memberships for the authenticated subject. Every Organisation-scoped endpoint verifies membership for the requested Organisation.

### Organisation content

```http
GET /v1/admin/organisations/:organisationId/content
PUT /v1/admin/organisations/:organisationId/content
```

PUT uses an expected revision and returns `409 EDIT_CONFLICT` for stale writes. Existing `/v1/admin/course-pack` endpoints remain temporarily as SYC compatibility adapters.

### Assets

```http
POST /v1/admin/organisations/:organisationId/assets/uploads
POST /v1/admin/organisations/:organisationId/assets/uploads/:uploadId/complete
GET  /v1/admin/organisations/:organisationId/assets/:assetId
```

Use presigned object-storage uploads rather than sending PDFs as JSON data URLs. Completion verifies size and hash before creating the asset record.

### Events

```http
GET  /v1/admin/organisations/:organisationId/events
POST /v1/admin/organisations/:organisationId/events
GET  /v1/admin/organisations/:organisationId/events/:eventId
PUT  /v1/admin/organisations/:organisationId/events/:eventId
POST /v1/admin/organisations/:organisationId/events/:eventId/publish
POST /v1/admin/organisations/:organisationId/events/:eventId/archive
```

Event PUT uses optimistic revision checks. Owners and publishers may publish; editors may edit drafts.

### Commercial administration

```http
GET  /v1/admin/organisations/:organisationId/entitlements
GET  /v1/admin/organisations/:organisationId/event-credits
POST /v1/internal/organisations/:organisationId/entitlement-grants
POST /v1/internal/organisations/:organisationId/event-credit-transactions
```

Internal mutation endpoints require an operational authentication boundary separate from club administrator tokens. No billing-provider endpoint is required in the first implementation slices.

### Public competitor API

```http
GET /v1/public/events/:publicId
GET /v1/public/events/:publicId/manifest
GET /v1/public/events/:publicId/publications/:publicationNumber/manifest
```

The latest manifest endpoint returns or redirects to the latest immutable publication. Published manifests and their referenced assets are public; drafts are never addressable through public IDs or object keys.

The web deep link is:

```text
/e/:publicId
```

The QR code contains this public identity, not an entitlement or secret.

## Event publication workflow

The publish operation:

1. Authenticates the administrator.
2. Verifies owner or publisher membership.
3. Loads the Event and current Organisation content.
4. Verifies the submitted Event revision.
5. Resolves referenced shared Courses and Documents.
6. Adds Event Courses, Event Documents, Notices, Races, required Marks, and public Organisation branding.
7. Validates all references and immutable assets.
8. Builds deterministic manifest bytes and SHA-256.
9. Starts a MongoDB transaction.
10. Re-reads Event and commercial state.
11. Checks active `PLATFORM_ACCESS`.
12. For first publication, checks unlimited publishing or usable credit balance.
13. Inserts the idempotent `CONSUME` transaction when required.
14. Determines the next publication number from authoritative publications.
15. Inserts the immutable `EventPublication`.
16. Updates Event status, `firstPublishedAt`, and `latestPublicationId`.
17. Commits and returns the public Event URL.

The request accepts an idempotency key, but correctness is also protected by unique database constraints. A retry after successful first publication returns the existing result and cannot consume another credit.

MongoDB transaction support must be confirmed in the chosen deployment. The legacy activation flow deliberately supports standalone MongoDB, but Event publication has stronger multi-collection atomicity requirements.

## Editing a published Event

- Editing changes the mutable Event working record.
- Competitors continue receiving the latest successful EventPublication.
- The admin UI indicates unpublished changes.
- Republishing creates a new immutable publication number.
- Republishing never consumes another Event Credit.
- Prior manifests and assets remain available.
- Changing Organisation content never silently changes a published Event.
- A resolved-manifest hash comparison is sufficient for V1 unpublished-change detection.

## Repository implementation boundaries

Keep one deployable Fastify/MongoDB service. Do not introduce microservices.

Retain the existing activation routes, entitlement signing, Auth0 verification, MongoDB lifecycle, privacy-aware logging, stable error format, and in-memory repository testing approach.

Grow toward these internal modules:

```text
licensing-server/src/
  identity/
    authenticator.ts
    membershipRepository.ts
    access.ts

  organisations/
    models.ts
    repository.ts
    routes.ts
    contentValidation.ts

  events/
    models.ts
    repository.ts
    routes.ts
    manifestBuilder.ts
    publicationService.ts

  commercial/
    models.ts
    repository.ts
    capabilityService.ts
    creditService.ts
    internalRoutes.ts

  assets/
    models.ts
    repository.ts
    objectStorage.ts
    routes.ts

  legacyLicensing/
    ...existing licensing modules...
```

Introduce modules incrementally. Do not begin with a large file move that obscures functional changes. New repositories may initially share the existing MongoDB connection.

### Web administration

Evolve the existing files under `src/admin/` into:

```text
src/admin/
  organisations/
  content/
  events/
  publishing/
  commercial/
  assets/
```

- Retain the current Course and Mark screens and point them at `OrganisationContent`.
- Move Notices from Course Pack navigation into Event editing.
- Replace frontend-embedded administrators with Membership endpoints.
- Separate saving Organisation content from publishing an Event.
- Organisation content publication is not monetised and does not create competitor content.

### Build and import pipeline

Retain `scripts/course_pack.mjs` as a legacy and import adapter. Later add import/export scripts that:

- seed Organisation content from a course pack;
- preserve old pack/Course IDs as migration aliases;
- upload referenced documents and charts;
- validate navigation references;
- export deterministic Event manifests for diagnostics.

Keep existing native resource generation until runtime Event downloads are proven.

### Native applications

Do not replace static native repositories immediately. Add an Event repository boundary alongside bundled loading:

```text
EventRepository
  bundledLegacyEvents()
  downloadedEvents()
  install(publicId)
  latestInstalledPublication()
```

Later native components are:

```text
BundledLegacyContentRepository
DownloadedEventRepository
EventManifestVerifier
EventDeepLinkHandler
```

Map published manifest Courses and Marks into the existing presentation and navigation models. Retain iOS `ClubAccessStore` and Android `ClubAccessManager` until migrated competitor access has shipped and legacy obligations are confirmed.

## Migration and implementation order

### Phase 0: protect the current baseline

- Inventory and commit current licensing, admin, and Notice work as a known baseline.
- Classify generated resources and source assets intentionally.
- Run existing web, server, iOS, and Android tests.
- Record which current features are prototypes versus production commitments.

### Phase 1: Organisation and memberships

- Add Organisations and multi-Organisation Memberships.
- Seed SYC as an Organisation.
- Link the existing SYC legacy Club through migration metadata.
- Copy current administrator memberships.
- Add Organisation selection to the admin web app.
- Retain `/v1/admin/course-pack` compatibility.

No competitor behaviour changes.

### Phase 2: Organisation content

- Add `organisationContent`.
- Import the current SYC course-pack draft.
- Remove members and notices from the content payload.
- Point existing Course and Mark administration at the new endpoints.
- Retain the existing pack export/build pipeline.

### Phase 3: object storage

- Add the object-storage adapter and `assets` metadata.
- Migrate the Fixed Course Guide, Standard SIs, relevant NTC PDFs, and charts.
- Stop introducing new PDF data URLs.
- Keep bundled native copies for compatibility.

### Phase 4: Events without commercial enforcement

- Add Event CRUD.
- Embed Races and Event-specific resources.
- Move or copy the existing SYC Notice into an Event with reviewed Race applicability.
- Build deterministic manifest validation and snapshot generation.
- Support private preview publication behind a non-production control.

### Phase 5: public publication and access

- Add immutable Event publications.
- Add `/e/:publicId` and public manifest endpoints.
- Publish an initial SYC test Event.
- Verify historical snapshots and asset retention.
- Add native deep-link and offline repositories while retaining bundled content.

### Phase 6: internal entitlements and credits

- Add entitlement grants and Event Credit transactions.
- Seed manual and migration grants.
- Represent SYC Founding Partner status using ordinary grant records.
- Add capability queries.
- Add transactional first-publication credit consumption.
- Enable enforcement only after reconciliation and concurrency tests pass.

### Phase 7: competitor licensing transition

- Allow public Fairlead Events to open without competitor activation.
- Retain legacy activation for old bundled variants and contractual snapshots.
- Stop using `permittedPackIds` for new public Event access.
- Monitor legacy activation usage.
- Retire legacy licensing only through a later explicit decision.

### Phase 8: billing adapter

- Add an idempotent provider webhook inbox.
- Translate provider events into internal grants and credit transactions.
- Keep prices and product IDs outside the core domain.
- Reconcile provider state against Fairlead commercial records.

## Recommended first coding slices

1. Organisation and multi-membership persistence without removing existing UI.
2. Read-only Organisation selection in the admin UI.
3. `OrganisationContent` migration while retaining Course and Mark screens.
4. Object-storage abstraction and one document upload flow.
5. Event draft CRUD without publication.
6. Deterministic manifest builder with focused tests.
7. Immutable non-commercial publication.
8. Public Event web view and deep link.
9. Internal grants and Event Credit ledger.
10. Transactional monetised first publication.
11. Native Event download and deep-link support.
12. Legacy activation retirement work only after migration evidence supports it.

## Explicitly deferred from V1

- Separate User records beyond external identity subjects.
- Per-resource Course, Mark, and Document revision collections.
- Generic polymorphic resource bindings.
- Standalone Race aggregates.
- Standalone reusable Course Collections.
- Course Guide generation definitions.
- Track-latest versus pin-version policies.
- Per-resource approval workflows.
- Document supersession graphs.
- Configurable permission engines.
- Expiring Event Credit lots and allocation ordering.
- Credit reservations and cached balance projections.
- Provider-specific billing domain concepts.
- Fully structured Course Designer geometry and advanced step types.
- Separate Course presentation/layout aggregates.
- Cross-Event asset deduplication workflows.

Stable IDs and immutable EventPublication manifests preserve migration paths to these capabilities without changing previously published competitor content.
