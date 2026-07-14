# Festival of Sails 2026 Course Pack Assessment

Status: design and draft data only. No application code or production asset has been changed. The draft must be manually compared with the official Sailing Instructions before use.

## Sources reviewed

- 2026 Festival of Sails Sailing Instructions, consolidated 20 January 2026 edition including Amendment #1 (60 PDF pages).
- Sailing Instruction Amendments, Amendment #1, issued 20 January 2026.
- Festival of Sails 2026 Official Notice Board.
- Race Committee Intentions for Sunday 25 January and Monday 26 January, used only to test operational/event-instance concepts.

The SI version history states "Final for publication" on 16 January and Amendment #1 on 20 January. The event dates are Wednesday 21 to Monday 26 January 2026 (SI PDF p.2). The noticeboard's current SI file is byte-identical to the supplied URL at the time of extraction.

## Existing repository model

### Marks

`Mark` is a globally identified, coordinate-bearing point: `id`, `name`, aliases, mandatory latitude/longitude, optional description, and coordinate status. There is no pack, mark type, permanence, coordinate source, dynamic placement rule, composite line/gate, or default rounding side.

`marks.json` is one global list. Lookups normalize a route row's mark string and search globally. `Start` and `Finish` are hard-coded aliases for `SYC 4`, which is an SYC-specific assumption rather than course data.

### Fixed courses

`fixed-courses.json` is a global array of `Course`. A course is identified by an integer `courseNumber` and contains an optional route string, pass instruction, course rows, total-distance string, diagram path/alt text, data status, one source page, and an optional comparison note.

Each `CourseLeg` stores `mark`, `side`, `bearing`, and `distance` as display strings. The row's mark is a name, not a mark ID. Start, finish, total, and pass rows share the same shape as navigation legs.

### Existing Laid Courses

`laid-courses.json` uses exactly the same `Course`/`CourseLeg` structure. Its course numbers are 80-98, its dynamic marks are tokens such as `1`, `3`, `4`, `Gate`, `Start`, and `Finish`, and their positions are not modelled. The route topology and rounding text are stored, but placement rules, gate choices, offset marks, substitutions, and race-day values are not.

The application infers "laid" from `courseNumber >= 80`; it disables active navigation for those courses. Festival windward/leeward courses should remain user-facing **Laid Courses**, but the data layer needs to distinguish a laid-course template from the dynamic marks used by that template.

### Side, distance, bearing, diagrams, numbers and flags

- Side, bearing, and distance are unvalidated strings per row.
- Diagram is a single asset path plus alt text on the course.
- Course number is both display value and global identity.
- Numeral pennants are generated from the integer course number. The model cannot express stacked `1 over 4`, a code flag, lights, or no course signal.
- Source provenance is a single page integer without a source-document identity or section.

### One-course-set assumptions

1. Global `fixedCourses`, `laidCourses`, and `marks` files.
2. Integer course lookup and navigation route `course/{number}`.
3. Recents and active course persist only the integer.
4. Active mark persists only a string.
5. Numeric range 80+ defines Laid Courses.
6. Start/finish lookup and active-course polyline seed `SYC 4` directly.
7. Diagram names and GPX/course labels are based on a global number.
8. Mark names and aliases must be globally unique.
9. A mark must have one coordinate; lines, gates, relative/dynamic marks, and missing coordinates are impossible.
10. An active course is assumed to have fixed resolvable point marks.
11. Race tracks do not snapshot pack/course/version context.

## Festival extraction and classification

### Permanent or charted marks

- Alcoa Inner and Alcoa Outer lead beacons.
- Hopetoun Channel gates formed by beacons 1/2 and 9/10. The SI publishes one approximate coordinate per gate, not endpoint coordinates.
- Outer Explosives Beacon.
- Pt Richards Entry Cardinal.
- Pt Wilson Pier Special Marks 3 and 4.
- Red lateral beacon pile at Prince George Light.

### Temporary marks with published approximate coordinates

- Cat 6 Laid Mark.
- CB 1 through CB 6.
- FoS 1 through FoS 7.

These are event-laid or inflatable marks, but unlike a normal Laid Course mark they have published approximate positions. Permanence and position mode therefore need separate fields.

### Dynamic marks and lines

- Melbourne northern/southern start lines: dynamic within a published vicinity.
- Mornington start: defined by physical objects, with only a published vicinity coordinate.
- Passage finish: approximately 400 m northeast of RGYC Marina; no coordinate.
- Special-course inner/outer starts and common finish.
- Special first laid mark: 0.5-0.9 nm approximately windward, blue for Line A or pink for Line B; side set by red/green flag; omitted when neither flag is shown.
- Windward/leeward start, Mark 1, change mark, optional offset, gate mark(s), and finish.
- Optional inner starting-distance marks are line-control features, not route waypoints.

The special first laid mark is deliberately configured as a conditional table leg with `map: omit`. This matches the SI: it appears in every special-course table but is not plotted on the course diagrams.

### Passage courses

1. Melbourne to Geelong: fleet-selected northern/southern start; conditional Cat 6/J24 mark to port; FoS 1 starboard; Alcoa Outer port; gates 1/2 then 9/10; dynamic Geelong finish (Appendix J, PDF pp.19-22).
2. Mornington to Geelong: Mornington line; Prince George red lateral port; Pt Richards Entry Cardinal port; FoS 1 starboard; Alcoa Outer port; gates 1/2 then 9/10; dynamic Geelong finish (Appendix J, PDF pp.23-25).

Both are complete route tables, but neither is fully map-renderable without race-day start/finish positions. The fixed intermediate geometry is renderable.

### Special fixed-mark courses

Special Courses 1-9 and 11-14 have complete ordered tables and published approximate positions for their named fixed/event marks (Appendix J, PDF pp.32-57). Each also has a dynamic start, conditional table-only first laid mark, and dynamic finish. Course 10 is intentionally blank and is not selectable.

Signals are numeral pennants 1-9, then stacked pennants 1/1, 1/2, 1/3, and 1/4. Amendment #1 specifically corrects Course 14 to `1 over 4`.

### Laid Course templates

Windward/Leeward Courses 1-3 are proper Laid Courses. They encode route topology but no permanent geometry (Appendix J, PDF pp.26-27):

- Course 1: Start - 1 - optional offset - Finish.
- Course 2: Start - 1 - optional offset - Gate - 1 - optional offset - Finish.
- Course 3: Start - 1 - optional offset - Gate - 1 - optional offset - Gate - 1 - optional offset - Finish.

All windward marks are rounded to port. A two-mark gate permits either rounding; a single gate mark is rounded to port. A black-banded change mark can substitute for Mark 1.

### Race areas and applicability

- Special-course starts may be inner (north of RGYC Marina) or outer (northeast of Alcoa Inner); the actual start area is communicated by SMS/noticeboard.
- Appendix K diagrammatically identifies inner, outer, windward/leeward north, and windward/leeward south areas. Boundaries and coordinates are not specified.
- Start Line A groups rating, multihull, Australian Multihull, and double-handed fleets.
- Start Line B groups spinnaker, Mornington Peninsula, non-spinnaker, and mini fleets.
- Start Line C is used for Australian Multihull windward/leeward racing and S80/J24 racing.
- The series appendices determine applicable course type and day. They should be filter metadata, not duplicated route geometry.
- The SI calls Double-Handed Sunday racing a `Long Special Course` but does not identify a distinct LSC route.

The Sunday and Monday Race Committee Intentions demonstrate a useful later concept: an **event instance** can select a base course, start lines, dynamic marks, finish, fleet assignment, and date. They should not mutate the base course pack. The Sunday notice itself needs verification: its text says Race 2 uses Course 1, while the image heading says Course 11.

### Reference-only material

Keep these as source-linked notes or optional safety overlays, not route legs:

- class flags, start order, schedules, VHF/SMS procedures, time limits, and reporting;
- start-area selection and race-day intentions;
- commercial-shipping rules;
- exclusion zones around channel infrastructure, Point Wilson (when activated), and marine farms;
- general shortening provisions;
- race-area diagrams without authoritative geometry.

The marine-farm coordinates are retained as non-route safety geometry. Portarlington's published southwest coordinate duplicates its southeast coordinate; Clifton Springs' labelled corners produce unusual geometry. Neither should be rendered before manual verification.

## Assessment of Course Pack design

The proposed pack handles Festival well if it treats identity, route topology, positioning, and presentation as separate concerns. It successfully represents:

- duplicate display numbers across packs and course families;
- existing Laid Courses as templates;
- mixed fixed/dynamic special courses;
- temporary marks with published coordinates;
- dynamic, relative, optional, conditional, composite-gate, and substitution concepts;
- course signals independent of identity;
- applicability and race areas;
- source/version provenance and unresolved ambiguity.

The largest conceptual change is not multi-pack loading itself. It is replacing the assumption that a course is wholly fixed or wholly laid with per-mark positioning and per-leg conditions.

No Festival route is unconditionally fully map-renderable from the SI alone. Special and passage routes have renderable fixed geometry but dynamic endpoints; Laid Courses require race-day positions. That is an honest and useful result rather than a pack failure.

## Smallest recommended model amendments

1. Add `CoursePack` metadata and load a list of packs. Keep the existing SYC JSON as one migrated pack.
2. Give each course a stable string `courseId`; retain `courseNumber` or `displayCode` only for presentation.
3. Give each mark a namespaced `markId`; resolve legs by ID, never display text.
4. Replace `courseNumber >= 80` with an explicit `courseCategory`, preserving `laid-course-template` as the existing Laid Courses family.
5. Make coordinates optional through a `position` union: fixed/published approximate, dynamic, relative, line, gate, or defined-by-objects.
6. Extend route legs with `action`, `side`, `condition`, `optional`, and `renderPolicy`. Existing SYC rows map directly to ordinary legs.
7. Add structured signals (`numeral`, `stacked numerals`, `flag`, `lights`) independent of course ID.
8. Add pack-level `raceAreas`, applicability profiles, sources, and reference notes. Avoid copying schedules into each route.
9. Use a composite persisted selection `(packId, courseId)` for recents, favourites, active course, deep links, track metadata, and exports.
10. Make start/finish definitions course data. Remove global `Start/Finish -> SYC 4` and active-polyline seeding.

This is intentionally evolutionary: the current `bearing`, `distance`, diagram, alt text, pass instruction, and display rows can remain during migration. They do not need a simultaneous redesign.

## Validation report

### Unresolved marks and missing coordinates

- Individual Hopetoun gate endpoints.
- MYC tower/orange-spar endpoints.
- All committee-vessel and pin endpoints.
- Special start, first laid mark, and finish.
- Passage finish.
- All windward/leeward marks and lines.
- Diagram-only race-area boundaries.

### Ambiguous or conditional navigation

- Special first laid mark: A/B variant, red/green side, or deleted.
- Windward gate: either endpoint or a single mark to port.
- Windward offset: only when laid, after every Mark 1 rounding.
- Windward change mark: substitutes for Mark 1.
- Melbourne Cat 6 leg: J24/Category 6 only.
- Special start area and finish placement: race-day state.

### Manual source checks

- Recompare every converted coordinate and route row with the SI.
- Confirm whether gate coordinates are midpoints or identify one component.
- Resolve Portarlington southwest coordinate duplication.
- Verify Clifton Springs exclusion-zone corner labels/order.
- Resolve Appendix H/I calendar-date inconsistencies.
- Identify the Double-Handed `Long Special Course` route.
- Confirm Cat 6/J24 terminology.
- Resolve Sunday Race 2 Course 1 versus Course 11 image heading.
- Confirm inferred inner/outer associations for special-course diagrams; the SI selects start areas operationally rather than per course.

## Implementation plan (no implementation performed)

1. Freeze and manually review the draft data against the SI.
2. Define a backward-compatible schema and migrate current SYC fixed/laid JSON into `syc/<courseId>` and `syc/<markId>` identities.
3. Update repository lookup and navigation/persistence to use `(packId, courseId)`; include a one-time migration from integer preferences.
4. Add position/leg resolution. Table rendering always shows route legs; map rendering filters by `renderPolicy` and only plots resolved point geometry.
5. Keep Festival windward/leeward routes in the Laid Courses UI. Permit optional race-day coordinate entry later without requiring it for pack import.
6. Add pack selection/filtering and explicit signal rendering.
7. Validate references, ID uniqueness, coordinate ranges, missing route marks, conditions, and pack version in tests.
8. Only after manual approval, copy the draft into a production asset and enable the Festival pack.

## Draft data

The companion `festival-of-sails-2026.draft.json` contains the complete extracted draft, namespaced identities, original coordinate text plus decimal conversion, all 13 special routes, three Laid Course templates, two passage routes, reference-only instructions, safety zones, and machine-readable validation findings.
