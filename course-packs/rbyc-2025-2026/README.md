# RBYC 2025-26 course-pack source notes

Parsed from `reference-course-books/RBYC-Keelboat-Sailing-Instructions-2025-2026-v6.pdf`.

- Fixed-mark coordinates: PDF page 3.
- Boat Start/Boat Finish laid courses: Appendix A, page 8.
- Boat Start/Tower Finish Courses 4-49: Appendix B, pages 9-10.
- Tower Start/Tower Finish Courses 50-99: Appendix C, pages 11-12.
- Courses 1-3 have four class-specific variants and retain their official signal number with unique
  identity suffixes.
- Temporary laid marks, gates and committee-vessel lines require race-day positions.
- The Race Control Tower has no coordinate in the source. Navigation defaults use published RBYC 6
  only and do not claim a complete georeferenced tower start/finish line.
- The source prints R2 as `37° 54' 54S`; this pack interprets it as `37° 54.54' S` and flags the
  coordinate as typographically ambiguous.

Regenerate course JSON from the authoritative PDF with:

```bash
python3 scripts/extract_rbyc_courses.py
```
