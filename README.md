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

The native app is bundled for offline use. It reuses the web app data by processing these sources into
Swift Package resources:

```bash
node scripts/build_ios_resources.mjs
```

That command copies fixed courses from `source/extracted-courses.json`, laid courses from
`source/extracted-laid-courses.json`, mark coordinates from `src/data/marks.ts`, chart PNGs from
`public/course-charts`, and numeral pennant SVGs from `src/assets/pennants`.

To update course data or mark coordinates, update the existing web source files first, run the resource
script, then rebuild the iOS app. To test offline use, install the app on a simulator/device, disable
network access, and confirm Home, course browsing, charts, flags, Quick Bearing, and Start Assist still
open from bundled resources.

Start Assist is intentionally limited: it calculates gun time plus start offset, distance/bearing to
SYC 4, SOG-based time to mark, time to start, and time to burn. It does not provide laylines, VMG,
polars, start-line geometry, race tracking, or tactical recommendations.
