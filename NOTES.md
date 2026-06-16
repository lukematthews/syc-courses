# SYC Courses Notes

## Working Directory

This is the Git-backed project copy:

```text
/Users/luke-home/syc-courses-github
```

The original scratch/build directory used earlier was:

```text
/Users/luke-home/syc-courses
```

Use the Git-backed copy going forward.

## Repository

Remote:

```text
git@github.com:lukematthews/syc-courses.git
```

Main branch has been pushed several times. Latest pushed work included the Flags quick-select feature.

## Commands

Install:

```bash
npm install
```

Run locally:

```bash
npm run dev -- --host 0.0.0.0
```

Build:

```bash
npm run build
```

Validate:

```bash
npm run lint
npm run build
```

## App Summary

SYC Courses is a static offline-first React/Vite/TypeScript/Tailwind PWA for race-day sailing course lookup.

Core screens:

- Home
- Course detail
- Flags
- Quick Bearing

Home currently includes:

- Quick Bearing
- Flags
- Collapsible Fixed Mark Courses
- Collapsible Laid Courses

Recently Viewed was removed from the active UI for now.

## Course Data

Fixed mark courses:

- Courses 1-68
- Source PDF: `source/SYC-2025-28-Course-Booklet_Rev_0.pdf`
- Data: `src/data/courses.ts`
- Extracted JSON: `source/extracted-courses.json`
- Chart crops: `public/course-charts/course-01.png` through `course-68.png`

Laid mark courses:

- Courses 80-98
- Source PDF: `source/Club-sailing-Instructions-2025-28_Rev-0.pdf`
- Data: `src/data/laidCourses.ts`
- Extracted JSON: `source/extracted-laid-courses.json`
- Chart crops: `public/course-charts/course-80.png` through `course-98.png`

Extraction scripts:

- `scripts/extract_courses.py`
- `scripts/extract_laid_courses.py`

## Flags

The Flags screen uses SVG numeral pennants:

```text
src/assets/pennants/numeral-0.svg
...
src/assets/pennants/numeral-9.svg
```

The Flags screen also has Quick Select:

- tap flags to build a course number
- selected flags display stacked
- Go opens a matching fixed or laid course
- Delete removes the last digit
- Reset clears selection

Leading zero is effectively ignored because no course starts with `0`.

## Quick Bearing

Quick Bearing uses browser geolocation and mark coordinates from page 3 of the fixed course booklet.

Files:

- `src/data/marks.ts`
- `src/hooks/useCurrentPosition.ts`
- `src/utils/navigation.ts`
- `src/components/QuickBearingResult.tsx`

Bearings currently display as true bearings because:

```ts
MAGNETIC_VARIATION_DEGREES = null
```

Set that constant in `src/utils/navigation.ts` to display magnetic bearings.

Important iOS note:

- GPS is reliable only from HTTPS or localhost.
- `http://192.168.x.x` may not allow geolocation in iOS Safari/Chrome/PWA.
- For real phone testing, deploy via Vercel/Netlify or another HTTPS host.

## PWA

PWA setup is in `vite.config.ts` using `vite-plugin-pwa`.

The app precaches the shell plus all course chart images.

Build output:

```text
dist/
```

`dist`, `dev-dist`, and `node_modules` are ignored.

## Recent UI Decisions

- Course list sections use Radix Collapsible.
- Fixed and Laid sections default collapsed.
- Open state is remembered while using the app via module-level state in `CourseListScreen.tsx`.
- Open course sections scroll internally using `.course-scroll-panel`.
- Section headers use soft tinted colors:
  - Fixed: blue
  - Laid: amber
- Course cards are white so they contrast with tinted section backgrounds.
- Old chunky offset shadows were replaced with softer surface styling in `src/index.css`.

## Deployment

If Vercel is connected to the GitHub repo, pushes to `main` should auto-deploy.

Expected Vercel settings:

```text
Build command: npm run build
Output directory: dist
```

After deployment, install the PWA from Safari on iOS:

1. Open HTTPS site in Safari.
2. Share.
3. Add to Home Screen.

