# Pennant assets

Phase 1 uses hand-created SVG numeral pennants, based on the project-level `image.png` reference.
`src/data/pennants.ts` imports `numeral-0.svg` through `numeral-9.svg`, and
`src/components/PennantStrip.tsx` renders those assets for course numbers and the reference screen.

The original reference PNG is retained as `numeral-pennants.png` for visual comparison only.
