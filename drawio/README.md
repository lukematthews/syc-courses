# SYC Sailing Shapes for draw.io

`syc-sailing-shapes.xml` is an importable draw.io custom library for producing course diagrams.
Its entries are native draw.io objects rather than flattened screenshots, so labels, colours,
line weights, positions, grouping and copy/paste remain editable.

## Import

1. Open [diagrams.net](https://app.diagrams.net/) or draw.io Desktop.
2. Choose **File → Open Library From → Device**.
3. Select `syc-sailing-shapes.xml`.

The **SYC Sailing Shapes** section contains numbered marks, a gate, committee boat, start and
finish lines, wind and course arrows, and a neutral adjustable rounding arc.

The gate helper uses true circular arc commands with a fixed aspect ratio. The rounding helper uses
draw.io's native Arc shape: select the arc itself and drag its two orange diamond handles to adjust
the start and end angles. Resize it proportionally to preserve a circular rather than elliptical arc.
The start and finish lines are native connectors attached to the mark and committee boat, so moving
either endpoint automatically updates the dotted line.

## Editing and regeneration

Edit `generate_syc_sailing_library.mjs`, then run:

```bash
node drawio/generate_syc_sailing_library.mjs
```

The generated library follows draw.io's `mxlibrary` format and deliberately stores uncompressed
`mxGraphModel` templates so the source remains inspectable and version-control friendly.
