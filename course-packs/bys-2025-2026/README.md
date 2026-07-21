# BYS 2025-26 course-pack source notes

Parsed from `reference-course-books/BYS-Keelboat-Sailing-Instructions-2025-2026-v2.pdf`,
Addendum A, PDF pages 8-16.

- Fixed and hybrid routes: pages 8-9 and 11-14.
- Laid aggregate Courses 10 and 11: page 10.
- Club mark coordinates: page 15.
- Fixed navigation-mark coordinates: page 16.
- Division A/B routes retain their official course number and use `identitySuffix` for unique IDs.
- Page 14 prints `COURSE 52` above the Division B south-course row, with `53` visibly inserted below.
  The pack records that row as Course 53 Division B, matching the surrounding heading and sequence.
- Course 35 remains a placeholder because its route is published on the Official Notice Board.
- Channel marks whose coordinates are delegated to chart AUS 158 are preserved in course rows but are
  not added to `marks.json`; GPX export therefore fails safely rather than using invented coordinates.
- The club start/finish tower has no coordinate in the source. Navigation defaults use published BYS 0
  only, so the pack does not claim a complete georeferenced club line.
- On-the-water laid marks and committee-boat lines do not have fixed coordinates.

Regenerate the two course JSON files after editing the audited source table:

```bash
node scripts/build_bys_sources.mjs
```
