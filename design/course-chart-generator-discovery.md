# Self-rendered course charts: discovery report

Status: discovery complete; implementation intentionally paused at the data-access gate.

## Recommendation

Build the renderer, but keep the existing course PNGs as production assets until the new output has been reviewed course by course. Use:

- Vicmap Index Framework Line/Polygon for coastline and land;
- Victorian `BATHYMETRY_PORT_PHILLIP_ARC` for Port Phillip depth contours, once a human has obtained the dataset through DataShare;
- Geoscience Australia's national bathymetry grid only as a coarse fallback outside the Victorian dataset's footprint;
- course-pack marks and course rows as the authoritative route overlay;
- no AMSA aid-to-navigation data unless the project owner separately signs its licence and supplies the data.

SVG should be the canonical generated format. Optional PNGs can be rasterised for clients that need them. All geometry should be projected before layout; MGA Zone 55 is already implemented in the repository and is appropriate for the initial Victorian scope.

## Existing architecture

The repository already separates most of the required concerns:

- `course-packs/<pack>/pack.json` identifies source data and an asset namespace.
- Fixed and laid course JSON contains route rows plus a `chartImage` path.
- The generated web, iOS and Android course-pack resources all consume those static image paths.
- Marks have stable IDs, aliases and verified latitude/longitude values.
- `scripts/course_pack.mjs` namespaces chart paths per pack.
- `scripts/build_port_phillip_coastline.mjs` downloads, clips and simplifies Vicmap coastline/land geometry into an offline JSON asset.
- `scripts/build_android_mark_locations.mjs` already projects WGS84 coordinates to MGA Zone 55, chooses a padded aspect-correct viewport, places labels with simple collision scoring, emits SVG, and rasterises it with `rsvg-convert`.

The lowest-risk design is therefore a build-time generator beside the existing scripts, not runtime map rendering. Proposed boundaries:

```text
course-packs/<pack>/chart-config.json     club defaults, extents, theme
course-packs/<pack>/...courses.json      course definitions
src/generated/course-pack/marks.json     mark coordinates
chart-data/                              locally supplied source datasets (not generated output)
scripts/course-charts/                    projection, geometry, layout and SVG modules
generated/course-charts/<namespace>/      review-only SVG/PNG output at first
```

The renderer should initially accept an explicit fixture/course file and output directory. Production `chartImage` values must not be rewritten until visual review and a deliberate migration step.

## Data-source assessment

### 1. Victorian Port Phillip depth contours — preferred local source

The official [Port Phillip Bay Depth Contours at 1:25,000 dataset](https://discover.data.vic.gov.au/en_AU/dataset/port-phillip-bay-depth-contours-at-1-25000) describes line features for bathymetry across Port Phillip Bay. It is offered as DWG, DXF, file geodatabase, Shapefile, MIF, TAB and Extended TAB, and is licensed CC BY 4.0.

The full metadata says:

- source data period: 1971–2000;
- nominal layer scale: 1:25,000, with some source sheets at 1:5,000 and 1:2,500;
- collection: hydrographic surveys followed by manual/automated contour interpretation;
- depths are in metres, but source sheets use several offsets below AHD and some fallback chart-datum values;
- the data must not be used for navigation;
- its footprint spans approximately 144.25–145.125 E and 37.75–38.375 S, with an irregular bay-shaped boundary.

Coverage assessment from the published footprint and lineage:

| Test area | Coverage | Evidence/qualification |
| --- | --- | --- |
| SYC / Sandringham | Yes | Eastern-bay footprint; source lineage includes Mordialloc–South Melbourne. |
| Point Lonsdale, Queenscliff and western Bellarine shoreline | Yes | Southern/western footprint; lineage includes Port Phillip Entrance. Very near-shore detail still requires visual inspection after download. |
| Inner and outer Corio Bay | Yes | Western footprint; lineage explicitly includes Geelong Harbour and Approaches and St Leonards–Clifton Springs. |
| Water connecting those areas | Yes | Published footprint is continuous across Port Phillip; areas without detailed listed sheets may derive from older, smaller-scale fallback material. |

This is suitable for contextual depth bands and contour lines, not exact depths, clearance decisions or navigation. Its mixed dates and datums should not be normalised into implied precision. Contour labels should state metres, while the footer should identify the source, vintage range and “Not for navigation”.

Access blocker: DataVic's resource links hand off to DataShare's order/request flow. The layer is not present in the public Open Data Platform WFS capabilities under its published name. No dataset payload was downloaded because completing an order may require a person to accept site or supply terms. A project owner should obtain the Shapefile or file geodatabase and place it in a documented local import path before implementation proceeds.

### 2. Vicmap Index and Hydro — approved basemap sources

The official [Vicmap Index REST API](https://discover.data.vic.gov.au/dataset/vicmap-index-rest-api) provides the state border/coastline framework under CC BY 4.0 and is updated weekly. Its [ArcGIS FeatureServer](https://services-ap1.arcgis.com/P744lA0wf4LlBZ84/arcgis/rest/services/Vicmap_Index/FeatureServer) exposes Framework Line and Polygon layers. The repository already uses the equivalent public WFS and records attribution.

The official [Vicmap Hydro REST API](https://discover.data.vic.gov.au/dataset/groups/vicmap-hydro-rest-api) is also CC BY 4.0 and updated weekly. It contains water areas, shoreline-related boundaries, structures, and navigation points/lines such as buoys, beacons, rocks and reefs. For coastline it explicitly recommends Vicmap Index.

Recommendation: retain Vicmap Index as coastline/land authority. Consider Vicmap Hydro later for contextual structures or hazards only after its feature codes and currency have been audited. Do not silently treat Hydro navigation points as equivalent to the maintained AMSA aid-to-navigation register.

### 3. Geoscience Australia Bathymetry and Topography — coarse fallback

The official [Australian Bathymetry and Topography MapServer](https://services.ga.gov.au/gis/rest/services/Bathymetry_Topography/MapServer) supplies a nationwide 2009 grid at 0.0025 degrees (roughly 220–280 m locally), via ArcGIS export, WMS and WCS. It is CC BY 4.0.

The service cautions that nominal resolution is supported only where observations are dense; other areas use substantially coarser source models. It covers all four fixtures continuously, but is too coarse for believable inner-harbour or near-shore contours at course-chart scale. Use it to avoid a blank background outside the Victorian footprint, with styling that visibly communicates lower detail. Do not merge its values seamlessly with Victorian contours without recording source boundaries and datum differences.

### 4. AusSeabed — potentially useful, currently gated

The official [AusSeabed Marine Data Portal](https://portal.ga.gov.au/persona/marine) states that its bathymetry datasets are CC BY 4.0, not suitable for navigation or safety-at-sea products, and may contain supplied artefacts. The portal requires the user to acknowledge those terms before entering.

Because the agent cannot make that acknowledgement for the project owner, no portal search or download was performed and detailed Port Phillip holdings were not verified. A human can inspect the portal later for higher-resolution surveys in the four fixture areas and provide selected datasets with their metadata and attribution.

### 5. AMSA aids to navigation — excluded pending a signed licence

AMSA's official [Spatial Data Gateway](https://www.amsa.gov.au/safety-navigation/spatial-data/spatial-data-gateway) offers aids-to-navigation data in common formats, but states that access requires signing a licence agreement. The project must not ingest or redistribute that dataset without the owner completing that agreement and confirming its redistribution terms.

The prototype should use only course-pack marks and explicitly authored fixture marks. It may draw generic mark symbols, but must not claim to portray the complete or current navigation-aid network.

## Licensing and product requirements

Every generated chart should include, in readable text:

- “Not for navigation”;
- source attribution for every basemap layer actually used;
- dataset date/vintage or retrieval date where practical;
- a statement that official sailing instructions and race-day communications take precedence.

Generated metadata should also retain machine-readable source IDs, URLs, licence identifiers, retrieval dates, transformations and generator version. CC BY adaptations should be described as clipped, transformed, simplified and styled. Existing copyright-page wording for Vicmap is a good baseline.

The renderer must not copy, trace or imitate the visual design of AUS 143, Navionics or another proprietary chart. It should have its own restrained course-diagram language.

## Minimum proof of concept after the data gate

Implement only after an authorised Victorian contour file is available (or the owner explicitly chooses a GA-only coarse prototype):

1. Read GeoJSON or a pre-converted, repository-approved contour fixture; avoid committing a large raw source file until size and redistribution have been reviewed.
2. Project coastline, contours, marks and route geometry to MGA Zone 55.
3. Derive an extent from route points plus configurable padding, then fit the output aspect ratio.
4. Render water/land, a small set of depth bands, labelled contours, course legs with directional arrows, start/finish treatment, rounding-side cues, mark symbols and collision-managed labels.
5. Include a north arrow, scale bar, attribution and safety footer.
6. Produce deterministic SVGs for:
   - an existing SYC fixed course;
   - a Bellarine fixture around Point Lonsdale/Queenscliff;
   - a Corio Bay fixture spanning inner/outer water.
7. Visually inspect all three at phone size and zoomed size before wiring any generated chart into web, iOS or Android.

## Open decisions and risks

- Obtain the Victorian contour payload and confirm its actual feature schema, contour interval, encoding, CRS, size and redistribution practicality.
- Decide whether raw third-party data belongs in Git/LFS, in a release-time cache, or in a reproducible external download step.
- Confirm whether the old dataset is visually acceptable for a modern app even with prominent non-navigation messaging.
- Define how start lines and laid marks are represented when coordinates are conditional or race-day-specific.
- Add a validation rule for unresolved course-row mark names; a chart must fail rather than silently omit an unknown mark.
- Test label collision and route self-intersection on the longest existing courses before considering production replacement.

## Required next action

A human project owner should download/order `BATHYMETRY_PORT_PHILLIP_ARC` from DataShare without delegating acceptance of terms, retain the included licence/metadata, and provide the Shapefile or file geodatabase to the project. After that, implementation can start with a schema inspection and the three review-only SVG fixtures.
