# SYC Courses

Offline-first iPhone/PWA course reference for SYC sailing courses. The app is built for race-day use:
large tap targets, high contrast, course tables before charts, local data, and recently viewed courses
stored in `localStorage`.

## Run Locally

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

## Club administration

Open `/admin` to edit marks, courses, charts, administrator roles, and Notices to Competitors. In
local development it uses a browser-local preview workspace by default. For an authenticated shared
workspace, configure the web app with `VITE_AUTH0_DOMAIN`, `VITE_AUTH0_CLIENT_ID`,
`VITE_AUTH0_AUDIENCE`, and `VITE_ADMIN_API_URL`, and configure the matching Auth0 domain/audience
and allowed web origins on the licensing service. Auth0 proves identity; club membership and the
owner/publisher/editor role remain server-side.

Notice content is stored in structured JSON for readable offline presentation on iPhone and Android,
alongside the original PDF. Canonical notice files live in `course-packs/<pack>/notices`; the iOS
resource build and Android synchronisation scripts preserve them.

Preview the production PWA:

```bash
npm run preview
```

## Install/Test As PWA

1. Start `npm run preview`.
2. Open the preview URL on an iPhone or in Safari responsive mode.
3. Use Share -> Add to Home Screen.
4. Open the installed app once online so the service worker can cache the shell and assets.
5. Disable network access and relaunch the installed app.

## PDF Extraction Status

The source PDF has been downloaded to:

```text
source/SYC-2025-28-Course-Booklet_Rev_0.pdf
```

Phase 1 includes the complete app structure, verified table data for courses 1-68, and chart crops
for courses 1-68 generated from the source PDF. Laid mark courses 80-98 are sourced from Appendix
A.4 of the club sailing instructions PDF.

To regenerate extraction artifacts, follow the notes in `scripts/README.md`.

## Quick Bearing

The Quick Bearing screen and tappable course-table mark rows use the browser Geolocation API. GPS is
requested only after a mark is selected. Mark coordinates are sourced from the Page 3 marks table in
the SYC 2025-28 course booklet and stored in `src/data/marks.ts`.

Bearing calculations live in `src/utils/navigation.ts`. `MAGNETIC_VARIATION_DEGREES` is currently
`null`, so bearings display as true bearings (`T`). Set that constant to show magnetic bearings
(`M`).

## Native iPhone App

Version 2.0 uses a small iOS app target at `ios/SYCCoursesApp/SYCCoursesApp.xcodeproj` backed by
the Swift package in `ios/SYCCourses`. Open the Xcode project, select the `SYCCoursesApp` scheme,
and run it on an iPhone simulator or device.

The native app is bundled for offline use. Course Pack v1 selects one pack at build time and processes
its sources into Swift Package resources:

```bash
node scripts/build_ios_resources.mjs
```

The selected pack and its source paths are declared under `course-packs/`. That command generates a
runtime manifest, namespaced course identities, fixed and laid courses, mark coordinates, and chart
assets. See [COURSE_PACKS.md](COURSE_PACKS.md) for the pack schema, selection file, and Android/web
resource commands.

To update course data or mark coordinates, update the existing web source files first, run the resource
script, then rebuild the iOS app. To test offline use, install the app on a simulator/device, disable
network access, and confirm Home, course browsing, charts, flags, Quick Bearing, and Start Assist still
open from bundled resources.

Start Assist is intentionally limited: it calculates gun time plus start offset, distance/bearing to
SYC 4, SOG-based time to mark, time to start, and time to burn. It does not provide laylines, VMG,
polars, start-line geometry, race tracking, or tactical recommendations.

## Club Licensing Guides

- [Licensing operations guide](LICENSING_OPERATIONS_GUIDE.md): business-level procedures for adding
  clubs, issuing or rotating invitations, suspending access, reviewing adoption, and support.
- [Club member activation guide](CLUB_MEMBER_ACTIVATION_GUIDE.md): concise member-facing setup,
  offline-use, troubleshooting, safety, and privacy instructions.
- [SYC member distribution flow](SYC_MEMBER_DISTRIBUTION_FLOW.md): launch-ready member email,
  responsibilities, activation diagrams, support flow, and optional future link automation.
- [Licensing architecture](LICENSING_ARCHITECTURE.md): trust boundaries, wire format, policy,
  provisioning, recovery, and future runtime course-pack design.

## Native Android App

The native Android app lives in `android` and is implemented with Kotlin and Jetpack Compose. It
shares the same bundled course data, mark coordinates, course charts, and visual identity as the
iPhone app. Its application ID is `com.lukematthews.syccourses`, with Android 8.0 (API 26) as the
minimum supported version.

Android uses the same Railway club invitations and signed entitlement contract as iPhone. It
verifies Ed25519 signatures locally, encrypts the installation identity and refresh credential with
Android Keystore, retains verified bundled access offline, and preserves upgraded installations as
legacy bundled access. See [Android licensing](android/LICENSING.md).

Open the `android` directory in Android Studio, allow Gradle sync to finish, then run the `app`
configuration on an emulator or physical Android device. Location permission is required for
bearing, line-assist, and race-tracking features. The app connects directly to an Actisense W2K-2
using the configured TCP or UDP host and port on the boat Wi-Fi network.

Build and test from a terminal with a Java 17 runtime and Android SDK installed:

```bash
cd android
./gradlew testDebugUnitTest assembleDebug
```

After changing the canonical iOS course resources, refresh Android's bundled copies with:

```bash
./scripts/sync_android_resources.sh
```
