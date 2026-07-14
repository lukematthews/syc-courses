import { writeFile } from 'node:fs/promises'
import polygonClipping from 'polygon-clipping'

const output = new URL('../android/app/src/main/assets/port-phillip-coastline.json', import.meta.url)
// Includes a generous buffer around Port Phillip so the clipped data edge remains off-screen
// when the Race Tracker is zoomed all the way out around an SYC course.
const bounds = { west: 144.0, south: -39.0, east: 145.8, north: -37.2 }

async function fetchLayer(typeName) {
  const endpoint = new URL('https://opendata.maps.vic.gov.au/geoserver/wfs')
  endpoint.search = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeNames: `open-data-platform:${typeName}`,
    outputFormat: 'application/json',
    srsName: 'EPSG:4326',
    bbox: `${bounds.west},${bounds.south},${bounds.east},${bounds.north},EPSG:4326`,
  }).toString()
  const response = await fetch(endpoint)
  if (!response.ok) throw new Error(`Vicmap WFS returned ${response.status} ${response.statusText}`)
  return response.json()
}

const [lineGeojson, polygonGeojson] = await Promise.all([
  fetchLayer('fr_framework_area_line'),
  fetchLayer('fr_framework_area_polygon'),
])

const latitudeScale = 111_320
const longitudeScale = latitudeScale * Math.cos(-38.05 * Math.PI / 180)
const toMetres = ([longitude, latitude]) => [longitude * longitudeScale, latitude * latitudeScale]

function perpendicularDistance(point, start, end) {
  const [px, py] = toMetres(point)
  const [sx, sy] = toMetres(start)
  const [ex, ey] = toMetres(end)
  const dx = ex - sx
  const dy = ey - sy
  if (dx === 0 && dy === 0) return Math.hypot(px - sx, py - sy)
  const position = Math.max(0, Math.min(1, ((px - sx) * dx + (py - sy) * dy) / (dx * dx + dy * dy)))
  return Math.hypot(px - (sx + position * dx), py - (sy + position * dy))
}

function simplify(points, toleranceMetres = 18) {
  if (points.length <= 2) return points
  let furthestIndex = 0
  let furthestDistance = 0
  for (let index = 1; index < points.length - 1; index += 1) {
    const distance = perpendicularDistance(points[index], points[0], points.at(-1))
    if (distance > furthestDistance) {
      furthestDistance = distance
      furthestIndex = index
    }
  }
  if (furthestDistance <= toleranceMetres) return [points[0], points.at(-1)]
  return [
    ...simplify(points.slice(0, furthestIndex + 1), toleranceMetres).slice(0, -1),
    ...simplify(points.slice(furthestIndex), toleranceMetres),
  ]
}

const paths = lineGeojson.features
  .filter(feature => feature.properties?.feature_type_code === 'coast')
  .flatMap(feature => feature.geometry.type === 'MultiLineString' ? feature.geometry.coordinates : [feature.geometry.coordinates])
  .map(path => simplify(path).map(([longitude, latitude]) => [
    Number(longitude.toFixed(6)),
    Number(latitude.toFixed(6)),
  ]))
  .filter(path => path.length >= 2)

const clippingBox = [[[
  [bounds.west, bounds.south],
  [bounds.east, bounds.south],
  [bounds.east, bounds.north],
  [bounds.west, bounds.north],
  [bounds.west, bounds.south],
]]]
const landPolygons = polygonGeojson.features
  .filter(feature => ['mainland', 'island coastal'].includes(feature.properties?.feature_type_code))
  .flatMap(feature => {
    const multiPolygon = feature.geometry.type === 'MultiPolygon'
      ? feature.geometry.coordinates
      : [feature.geometry.coordinates]
    return polygonClipping.intersection(multiPolygon, clippingBox)
  })
  .map(polygon => polygon.map(ring => simplify(ring).map(([longitude, latitude]) => [
    Number(longitude.toFixed(6)),
    Number(latitude.toFixed(6)),
  ])))
  .filter(polygon => polygon.some(ring => ring.length >= 3))

const data = {
  source: 'Vicmap Index - Framework Line',
  sourceUrl: 'https://discover.data.vic.gov.au/dataset/vicmap-index-framework-line',
  attribution: 'Coastline © State of Victoria, CC BY 4.0',
  retrieved: new Date().toISOString().slice(0, 10),
  paths,
  landPolygons,
}

await writeFile(output, `${JSON.stringify(data)}\n`)
console.log(`Wrote ${paths.length} coastline paths and ${landPolygons.length} land polygons to ${output.pathname}`)
