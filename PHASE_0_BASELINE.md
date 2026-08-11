# Phase 0 baseline

Date: 2026-08-11

Phase 0 protects the existing SYC Courses implementation before Fairlead domain migration begins. It records what is present, how repository assets are classified, what has been validated, and what remains prototype or operationally deferred.

No Organisation, Membership, Event, EventPublication, commercial entitlement, or Event Credit implementation is included in this baseline. The accepted future architecture is documented in `FAIRLEAD_V1_ARCHITECTURE.md`.

## Baseline scope

This baseline preserves the previously uncommitted body of work as one known starting point:

- web/PWA course reference and navigation;
- native iOS course reference, navigation, race tracking, start/finish tools, and licensing;
- native Android equivalent functionality and licensing;
- Course Pack v1 build and native resource synchronisation;
- club invitation activation and signed installation entitlement service;
- Auth0-backed club administration API and web administration prototype;
- structured Notices to Competitors with bundled source PDFs;
- licensing, member-distribution, and operations documentation;
- Fairlead V1 architecture and migration plan.

## Implementation status

### Implemented and preserved contracts

- Course Pack v1 manifest, namespaced Course IDs, Mark IDs, course groups, navigation defaults, and generated resource formats.
- Bundled offline loading in the PWA, iOS app, and Android app.
- Course tables, charts, Quick Bearing, BTW/DTW-related navigation, active-course navigation, race tracking, start/finish assistance, and existing NMEA-facing functionality.
- Structured Notices to Competitors in iOS and Android, including access to the bundled authoritative PDF.
- Invitation activation, installation identity, refresh credentials, Ed25519 entitlement verification, expiry/grace evaluation, secure local persistence, and legacy bundled-access migration.
- Licensing API rate limiting, privacy-aware error/log behaviour, MongoDB indexes, and administrative licensing commands.
- Auth0 token verification and application-owned club administrator roles.
- Whole-course-pack draft persistence, optimistic revision checking, and immutable published-course-pack records.

These contracts may be migrated or adapted later, but Phase 1 must not silently remove them.

### Functional prototypes

- The web club administration UI is a functional prototype, not the final Fairlead administration information architecture.
- Local development administration defaults to a browser-local workspace.
- Remote administration stores one complete Course Pack draft per club as an opaque payload.
- Administrator display/member data is still embedded in the frontend `AdminPack` model even though server-side Auth0 membership also exists.
- Notices use free-text series and applicability because Event and Race models do not yet exist.
- Course chart and Notice uploads can be represented as browser data URLs; future Fairlead work must move binaries to object storage.
- Published Course Packs are content snapshots, not Fairlead Event publications.

### Operationally incomplete or deferred

- Production Railway, MongoDB, Auth0, key-management, monitoring, backup, and restore configuration has not been verified by this local baseline.
- Runtime Course Pack download, update, signature verification, and atomic installation are deferred.
- Competitor access is still gated by legacy device/installation licensing in native applications.
- Fairlead Organisations, multi-Organisation Memberships, Events, Races as Event data, EventPublication manifests, public Event deep links, internal commercial grants, and Event Credits are not implemented.
- Object storage is not provisioned.
- Billing-provider integration is not implemented.
- Course Designer is not implemented.
- Store-policy review and production release acceptance remain separate work.

## Asset classification

### Canonical authored and imported sources

These are inputs that should be edited or deliberately replaced:

- `course-packs/*/pack.json`: canonical pack definitions and source routing.
- `course-packs/*/fixed-courses.json`, `laid-courses.json`, and `marks.json` where a pack uses JSON inputs.
- `course-packs/syc/notices/`: canonical structured SYC Notice data and authoritative source PDFs.
- `source/`: SYC source PDFs and extracted intermediate Course data.
- `src/data/marks.ts` and other explicitly selected source modules named by pack definitions.
- `reference-course-books/`: external reference inputs; not runtime application state.
- `design/` and `drawio/`: editable design/tooling sources.
- application source under `src/`, `ios/`, `android/`, and `licensing-server/src/`.
- build and migration scripts under `scripts/` and `licensing-server/scripts/`.

### Generated but intentionally committed release resources

These files are derived but committed so web, Xcode, and Android builds work from a checkout:

- `src/generated/course-pack/`;
- generated Course JSON, manifests, charts, maps, hotspots, and Notice copies under `ios/SYCCourses/Sources/SYCCourses/Resources/`;
- corresponding generated assets under `android/app/src/main/assets/`;
- generated chart outputs under `public/course-charts/`.

Do not hand-edit generated copies when a canonical source or generator exists. Regenerate web resources with `npm run course-pack`, build iOS resources with `node scripts/build_ios_resources.mjs`, and synchronise Android with `bash scripts/sync_android_resources.sh`.

`public/course-charts/` contains a mixture of imported/authored and generated chart assets. Treat the directory as committed release input/output and use the pack-specific chart scripts rather than bulk deletion or renaming.

### Build products and local state

These are reproducible and ignored:

- `node_modules/`;
- root and licensing-server `dist/`;
- iOS `.build`, DerivedData, archives, results, and user IDE state;
- Android Gradle build directories;
- local `.env`, private keys, and developer overrides.

Secrets, private signing keys, local environment files, and production credentials must never be committed.

### Reference deliverables

`output/` and `outputs/` contain generated reference deliverables rather than runtime application state. They are retained when intentionally tracked but are not Fairlead domain persistence.

## Automated validation

The following checks passed against this baseline on 2026-08-11.

### Web/PWA

```bash
npm run lint
npm run build
```

The build regenerated Course Pack resources and produced the PWA successfully.

### Licensing and administration service

```bash
cd licensing-server
npm run check
npm test
npm run build
```

Result: 16 tests passed across licensing and club-administration suites.

### iOS Swift package

```bash
cd ios/SYCCourses
swift test
```

Result: 52 tests passed across Course identity/migration, active navigation, GPX export, licensing, navigation data/math, and race-track math.

This validates the Swift package. It does not replace simulator/device testing of the Xcode application target, URL handling, permissions, PDF presentation, secure storage, or release signing.

### Android

The shell does not have a global Java runtime configured. Use Android Studio's bundled JDK:

```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew testDebugUnitTest assembleDebug
```

Result: build successful, including Android unit tests and debug APK assembly. Android Gradle Plugin emitted existing deprecation warnings; they do not fail the baseline but should be addressed separately from Fairlead domain migration.

## Manual Phase 0 acceptance checklist

Complete these checks before approving Phase 1. They exercise behaviour that automated package/build tests do not fully cover.

### Web/PWA

1. Run `npm run dev`.
2. Open the main Course list and at least one fixed and laid Course.
3. Confirm chart, table, pennants, Quick Bearing UI, and recently viewed behaviour.
4. Open `/admin` without remote Auth0 configuration and confirm the local preview workspace loads.
5. Edit a Course and Mark, confirm validation and preview, then use the local reset mechanism if desired.
6. Open Notices administration and confirm the structured SYC Notice and PDF metadata appear.

### Licensing service

1. Copy the documented development environment values without using production secrets.
2. Start MongoDB and the service with `npm run dev` under `licensing-server/`.
3. Confirm `GET /v1/health` returns success.
4. Exercise a development invitation activation and refresh using the documented admin tooling.
5. If Auth0 development settings are available, confirm the admin Course Pack GET/save/publish flow and stale-revision conflict.

### iOS

1. Open `ios/SYCCoursesApp/SYCCoursesApp.xcodeproj` and run the SYC scheme on a simulator/device.
2. Confirm existing/legacy access migration or development activation reaches the home screen.
3. Confirm fixed and laid Courses, Quick Bearing, active-course navigation, Start Assist, race tracking, and Notices.
4. Open/share the original Notice PDF.
5. Disable network access and relaunch; confirm bundled reference content remains available according to the current access policy.

### Android

1. Open `android/` in Android Studio and run the debug app.
2. Confirm activation or legacy bundled access.
3. Confirm fixed and laid Courses, Quick Bearing, active-course navigation, start/finish tools, race tracking, and Notices.
4. Open the original Notice PDF using an installed PDF viewer.
5. Disable network access and relaunch; confirm bundled reference content remains available according to the current access policy.

## Phase boundary

Phase 0 is complete when:

- this baseline and the previously uncommitted work are committed together;
- automated validation remains green;
- the user has had an opportunity to run the manual acceptance checklist;
- no Phase 1 Organisation or Membership implementation has been included accidentally.

Phase 1 must begin as a separate change set and must remain independently testable before Phase 2 begins.
