# PDF extraction notes

The source PDF is stored at `source/SYC-2025-28-Course-Booklet_Rev_0.pdf`.

Courses 1-68 and chart crops have been extracted from the PDF. To regenerate the intermediate JSON
and chart PNGs:

```bash
python3 -m pip install pymupdf
python3 scripts/extract_courses.py
```

The script writes:

- `source/extracted-courses.json`
- `public/course-charts/course-01.png` through `public/course-charts/course-68.png`

`src/data/courses.ts` is the app-facing TypeScript data file generated from that extracted JSON.
