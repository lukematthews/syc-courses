# Course packs

Course Pack v1 bundles exactly one pack into each app build. The data model and persisted course
identities support more than one pack, but installing, updating, and selecting packs at runtime is
deliberately deferred.

## Selecting the bundled pack

[`course-packs/bundled-pack.json`](course-packs/bundled-pack.json) is the single build-time choice:

```json
{
  "packDirectory": "syc"
}
```

The value names a directory containing `course-packs/<packDirectory>/pack.json`. The current SYC
definition is in [`course-packs/syc/pack.json`](course-packs/syc/pack.json).

The manifest contains public pack metadata, supported course kinds, the pack's start/finish marks,
and an ordered `quickBearingMapViews` list. Each named map view can provide `fitMarkIds` to define
an area; the first view normally omits them to show the full pack overview. Build scripts remove
`buildSources` from the runtime manifest.

`courseGroups` controls the course cards shown by an app. Groups have a stable `id`, a display
`name`, and an underlying `kind` (`fixed` or `laid`). Each source course can select a `groupId`;
when omitted it defaults to its kind. This lets one shared app present pack-specific groupings such
as Fixed Mark, Fixed Division A, Fixed Division B and Laid Marks without hard-coded club logic.

Course IDs are generated as compound identities:

```text
<packId>/<kind>/course-<courseNumber>
```

When an official course number has multiple published variants, the source course can include an
`identitySuffix` such as `div-a`. The suffix is used only in the generated identity (for example,
`<packId>/fixed/course-12-div-a`) and is removed from the runtime course data. The displayed course
number remains the official numeral-pennant signal; the route label distinguishes the variants.

For example, SYC Course 4 is
`sandringham-yacht-club-2025-2028/fixed/course-4`. Course numbers remain display values and pennant
signals; they are not global identities.

## Building resources

Generate the web resources:

```bash
npm run course-pack
```

Generate iOS, then synchronise Android from the same selected pack:

```bash
node scripts/build_android_mark_locations.mjs
node scripts/build_ios_resources.mjs
bash scripts/sync_android_resources.sh
```

`npm run build` regenerates the web pack automatically. Generated manifests and JSON are committed
so Xcode, Android Studio, and local web development all work immediately after checkout.

Course charts are namespaced at `course-charts/<assetNamespace>/` on every platform to prevent
filename collisions between packs. The runtime manifest contains a generated `quickBearingMaps`
entry for every configured view so native clients can offer two-view zoom or a multi-area selector
without hard-coding a particular club's geography.

Fixed courses without an authored `chartImage` receive a deterministic generated chart. Routes
whose marks all resolve to published coordinates use a projected geographic diagram over the
offline Vicmap coastline. Routes with unresolved or race-day-only marks use a clearly labelled
schematic instead of inventing coordinates. Placeholder entries that publish no route at all remain
without a chart. SVG is retained as the canonical source and PNG is
embedded in the clients. Generate a pack explicitly with:

```bash
node scripts/build_course_charts.mjs bys-2025-2026
```

## Adding another bundled pack

Create a new `course-packs/<directory>/pack.json` and the files referenced by its `buildSources`, then
change `course-packs/bundled-pack.json` and run the resource builds above. The build validates the
manifest, unique compound course IDs, unique mark IDs, source paths, and navigation-default mark
references.

For v1, changing the bundled pack is a new application build. There is no user-facing pack picker,
download format, signature verification, or update service yet.

## iPhone app variants

Xcode app builds do not use `bundled-pack.json`. App branding and pack selection are registered in
[`course-apps.json`](course-apps.json), and the shared Xcode project exposes these schemes:

- `SYC Courses`
- `Festival of Sails Courses`
- `RYCV Courses`
- `RMYS Courses`
- `BYS Courses`
- `RBYC Courses`

Select a scheme and Run to install that variant in the simulator. Each scheme has distinct Debug
and Release configurations, product name, display name and bundle identifier, so completed variants
can coexist on the simulator and archive independently.

The Xcode build phase runs the equivalent of:

```bash
node scripts/build_ios_variant.mjs \
  --variant syc \
  --output /tmp/SYCCoursePackResources
```

The generator writes only to Xcode's derived-data directory. It copies the selected pack into
`CoursePackResources` inside the application bundle; it does not modify `bundled-pack.json` or the
committed Swift-package fallback resources. Runtime loading prefers the application-bundle variant,
while `swift test` continues to use the committed fallback.

SYC and Festival are buildable now. RYCV and RMYS have schemes, configurations and registry entries,
but intentionally fail with a clear message until `course-packs/rycv/pack.json` and
`course-packs/rmys/pack.json` are added. Do not point those variants at another club's data.

BYS is registered as the `bys` variant and available through the shared `BYS Courses` Xcode scheme.
Its bundle identifier and shared app icon are provisional until final branding is chosen.

Before App Store submission, replace the provisional non-SYC bundle identifiers in
`course-apps.json` and the corresponding files under `ios/SYCCoursesApp/Configs`, and add distinct
app-icon asset sets. The build validates registry display names and bundle identifiers against the
active Xcode configuration to catch accidental mismatches.
