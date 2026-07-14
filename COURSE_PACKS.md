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
and build-source paths. Build scripts remove `buildSources` from the runtime manifest.

Course IDs are generated as compound identities:

```text
<packId>/<kind>/course-<courseNumber>
```

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
node scripts/build_ios_resources.mjs
bash scripts/sync_android_resources.sh
```

`npm run build` regenerates the web pack automatically. Generated manifests and JSON are committed
so Xcode, Android Studio, and local web development all work immediately after checkout.

Course charts are namespaced at `course-charts/<assetNamespace>/` on every platform to prevent
filename collisions between packs.

## Adding another bundled pack

Create a new `course-packs/<directory>/pack.json` and the files referenced by its `buildSources`, then
change `course-packs/bundled-pack.json` and run the resource builds above. The build validates the
manifest, unique compound course IDs, unique mark IDs, source paths, and navigation-default mark
references.

For v1, changing the bundled pack is a new application build. There is no user-facing pack picker,
download format, signature verification, or update service yet.
