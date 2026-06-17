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

### Navigation Output v1

The iPhone app includes a first Navigation Output integration for Actisense W2K-2 only. The W2K-2
settings live in the native app under Navigation Output.

Implementation notes:

- Course and mark calculations stay independent of Actisense, TCP, UDP, Wi-Fi, and NMEA transport.
- `NavigationOutputService` owns enabled/disabled state, settings, diagnostics, and message dispatch.
- `ActisenseW2K2Adapter` owns W2K-2 connection state and sends ASCII NMEA 0183 sentences over TCP or UDP.
- v1 sends a small NMEA 0183 subset (`BWC` and `RMB`) for active waypoint, bearing, and distance data.
- Native NMEA 2000 PGN encoding is intentionally left for a later adapter rather than faking support.
- Public W2K-2 material is clearer about getting NMEA 2000 data out to Wi-Fi than app-generated
  navigation data back onto NMEA 2000. Treat this as transport-level output until confirmed on the boat.

Manual test notes:

1. Connect iPhone to W2K-2 Wi-Fi.
2. Open SYC Courses.
3. Go to Navigation Output settings.
4. Select Actisense W2K-2.
5. Enter the W2K-2 host/IP and data server port.
6. Connect.
7. Select a course.
8. Tap Send to Boat.
9. Confirm boat instruments show expected navigation fields if supported by the W2K-2 configuration and instruments.

### Actisense Boat Data Input v1

The native app can also read NMEA 0183-style boat data from an Actisense/W2K-2 network stream.
Input settings are intentionally minimal and live beside Navigation Output:

- enable Actisense input
- host/IP
- port
- TCP/UDP
- connection status and test connection

Supported input sentences in v1:

- `RMC` for position, SOG, COG, timestamp, and valid/invalid status
- `GGA` for position, fix quality, and HDOP
- `VTG` for COG/SOG updates
- `HDT`, `HDM`, and `HDG` for heading updates

Fresh valid Actisense data is preferred by Quick Bearing, Mark Detail, Course Send to Boat, and Start
Assist. If the Actisense feed is disconnected, invalid, or stale, those screens fall back to iPhone GPS.
