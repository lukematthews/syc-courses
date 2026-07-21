import { execFileSync } from 'node:child_process'
import { readdir, readFile, unlink, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { loadBundledCoursePack } from './course_pack.mjs'

// Requires rsvg-convert (librsvg) to rasterise the generated SVG without adding
// a JavaScript image-rendering dependency to the application project.

const width = 1215
const height = 1680
const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const coastlineUrl = new URL('../android/app/src/main/assets/port-phillip-coastline.json', import.meta.url)
const resourceDirectory = process.env.IOS_RESOURCE_DIR
  ? new URL(`file://${process.env.IOS_RESOURCE_DIR.replace(/\/$/, '')}/`)
  : new URL('../ios/SYCCourses/Sources/SYCCourses/Resources/', import.meta.url)

const pack = loadBundledCoursePack(root)
const marks = pack.marks
const coastline = JSON.parse(await readFile(coastlineUrl, 'utf8'))

for (const file of await readdir(resourceDirectory)) {
  if (/^mark-locations(?:-[a-z0-9-]+)?\.png$/.test(file) || /^mark-location(?:-[a-z0-9-]+)?-hotspots\.json$/.test(file)) {
    await unlink(new URL(file, resourceDirectory))
  }
}

const semiMajorAxis = 6_378_137
const inverseFlattening = 298.257223563
const centralMeridianDegrees = 147
const scaleFactor = 0.9996
const falseEasting = 500_000
const falseNorthing = 10_000_000

function project(latitude, longitude) {
  const flattening = 1 / inverseFlattening
  const eccentricitySquared = flattening * (2 - flattening)
  const secondEccentricitySquared = eccentricitySquared / (1 - eccentricitySquared)
  const latitudeRadians = latitude * Math.PI / 180
  const longitudeDifference = (longitude - centralMeridianDegrees) * Math.PI / 180
  const sinLatitude = Math.sin(latitudeRadians)
  const cosLatitude = Math.cos(latitudeRadians)
  const tangent = Math.tan(latitudeRadians)
  const radius = semiMajorAxis / Math.sqrt(1 - eccentricitySquared * sinLatitude ** 2)
  const tangentSquared = tangent ** 2
  const longitudeTerm = cosLatitude * longitudeDifference
  const curvature = secondEccentricitySquared * cosLatitude ** 2
  const e2 = eccentricitySquared
  const meridionalArc = semiMajorAxis * (
    (1 - e2 / 4 - 3 * e2 ** 2 / 64 - 5 * e2 ** 3 / 256) * latitudeRadians
      - (3 * e2 / 8 + 3 * e2 ** 2 / 32 + 45 * e2 ** 3 / 1024) * Math.sin(2 * latitudeRadians)
      + (15 * e2 ** 2 / 256 + 45 * e2 ** 3 / 1024) * Math.sin(4 * latitudeRadians)
      - (35 * e2 ** 3 / 3072) * Math.sin(6 * latitudeRadians)
  )
  return {
    easting: falseEasting + scaleFactor * radius * (
      longitudeTerm
        + (1 - tangentSquared + curvature) * longitudeTerm ** 3 / 6
        + (5 - 18 * tangentSquared + tangentSquared ** 2 + 72 * curvature - 58 * secondEccentricitySquared) * longitudeTerm ** 5 / 120
    ),
    northing: falseNorthing + scaleFactor * (
      meridionalArc + radius * tangent * (
        longitudeTerm ** 2 / 2
          + (5 - tangentSquared + 9 * curvature + 4 * curvature ** 2) * longitudeTerm ** 4 / 24
          + (61 - 58 * tangentSquared + tangentSquared ** 2 + 600 * curvature - 330 * secondEccentricitySquared) * longitudeTerm ** 6 / 720
      )
    ),
  }
}

function makeViewport(points) {
  const minEasting = Math.min(...points.map(point => point.easting))
  const maxEasting = Math.max(...points.map(point => point.easting))
  const minNorthing = Math.min(...points.map(point => point.northing))
  const maxNorthing = Math.max(...points.map(point => point.northing))
  const centreEasting = (minEasting + maxEasting) / 2
  const centreNorthing = (minNorthing + maxNorthing) / 2
  let viewportWidth = Math.max(maxEasting - minEasting, 8_000) * 1.3
  let viewportHeight = Math.max(maxNorthing - minNorthing, 8_000) * 1.3
  const aspect = width / height
  if (viewportWidth / viewportHeight < aspect) viewportWidth = viewportHeight * aspect
  else viewportHeight = viewportWidth / aspect
  return {
    left: centreEasting - viewportWidth / 2,
    right: centreEasting + viewportWidth / 2,
    bottom: centreNorthing - viewportHeight / 2,
    top: centreNorthing + viewportHeight / 2,
  }
}

const projectedMarks = marks.map(mark => ({ ...mark, projected: project(mark.latitude, mark.longitude) }))

function escapeXml(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;')
}

function overlapArea(a, b) {
  return Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left))
    * Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top))
}

async function renderMap(imageName, hotspotsName, viewportMarks, displayMarks = projectedMarks) {
  const viewport = makeViewport(viewportMarks.map(mark => mark.projected))
  const position = point => ({
    x: (point.easting - viewport.left) / (viewport.right - viewport.left) * width,
    y: (viewport.top - point.northing) / (viewport.top - viewport.bottom) * height,
  })
  const coordinatePosition = ([longitude, latitude]) => position(project(latitude, longitude))
  const pathForRing = ring => ring.map((coordinate, index) => {
    const point = coordinatePosition(coordinate)
    return `${index === 0 ? 'M' : 'L'}${point.x.toFixed(1)},${point.y.toFixed(1)}`
  }).join(' ') + ' Z'
  const pathForLine = path => path.map((coordinate, index) => {
    const point = coordinatePosition(coordinate)
    return `${index === 0 ? 'M' : 'L'}${point.x.toFixed(1)},${point.y.toFixed(1)}`
  }).join(' ')
  const markPositions = displayMarks
    .map(mark => ({ ...mark, ...position(mark.projected) }))
    .filter(mark => mark.x >= 0 && mark.x <= width && mark.y >= 0 && mark.y <= height - 36)
  const occupied = [
    { left: width - 105, top: 0, right: width, bottom: 80 },
    { left: 0, top: height - 42, right: width, bottom: height },
    ...markPositions.map(mark => ({ left: mark.x - 13, top: mark.y - 13, right: mark.x + 13, bottom: mark.y + 13 })),
  ]

  const labels = []
  for (const mark of [...markPositions].sort((a, b) => a.y - b.y || a.x - b.x)) {
    const fontSize = 29
    const labelWidth = Math.max(42, mark.name.length * fontSize * .59 + 18)
    const labelHeight = 39
    const candidates = [18, 34, 52, 72].flatMap(gap => [
      { x: mark.x + gap, y: mark.y - labelHeight / 2 },
      { x: mark.x - labelWidth - gap, y: mark.y - labelHeight / 2 },
      { x: mark.x - labelWidth / 2, y: mark.y - labelHeight - gap },
      { x: mark.x - labelWidth / 2, y: mark.y + gap },
      { x: mark.x + gap, y: mark.y - labelHeight - gap },
      { x: mark.x - labelWidth - gap, y: mark.y - labelHeight - gap },
      { x: mark.x + gap, y: mark.y + gap },
      { x: mark.x - labelWidth - gap, y: mark.y + gap },
    ])
    const scored = candidates.map(candidate => {
      const rect = { left: candidate.x, top: candidate.y, right: candidate.x + labelWidth, bottom: candidate.y + labelHeight }
      const outside = rect.left < 8 || rect.top < 8 || rect.right > width - 8 || rect.bottom > height - 48
      const overlap = occupied.reduce((sum, item) => sum + overlapArea(rect, item), 0)
      const distance = Math.hypot((rect.left + rect.right) / 2 - mark.x, (rect.top + rect.bottom) / 2 - mark.y)
      return { candidate, rect, score: overlap + (outside ? 10_000_000 : 0) + distance * .01 }
    }).sort((a, b) => a.score - b.score)
    const choice = scored[0]
    occupied.push(choice.rect)
    labels.push({ mark, ...choice.candidate, rect: choice.rect, fontSize })
  }

  const landPaths = coastline.landPolygons
    .map(polygon => polygon.map(pathForRing).join(' '))
    .map(path => `<path d="${path}" fill="#F3E4A6" fill-rule="evenodd"/>`)
    .join('\n')
  const coastPaths = coastline.paths
    .map(path => `<path d="${pathForLine(path)}" fill="none" stroke="#58717D" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>`)
    .join('\n')
  const leaders = labels.map(label => {
    const targetX = Math.max(label.rect.left, Math.min(label.mark.x, label.rect.right))
    const targetY = Math.max(label.rect.top, Math.min(label.mark.y, label.rect.bottom))
    return Math.hypot(targetX - label.mark.x, targetY - label.mark.y) > 28
      ? `<line x1="${label.mark.x.toFixed(1)}" y1="${label.mark.y.toFixed(1)}" x2="${targetX.toFixed(1)}" y2="${targetY.toFixed(1)}" stroke="#526B76" stroke-opacity=".58" stroke-width="2"/>`
      : ''
  }).join('\n')
  const labelElements = labels.map(label => `<g>
  <rect x="${label.rect.left.toFixed(1)}" y="${label.rect.top.toFixed(1)}" width="${(label.rect.right - label.rect.left).toFixed(1)}" height="${(label.rect.bottom - label.rect.top).toFixed(1)}" rx="6" fill="#FFFFFF" fill-opacity=".88"/>
  <text x="${(label.x + 9).toFixed(1)}" y="${(label.y + 29).toFixed(1)}" fill="#183746" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" font-size="${label.fontSize}" font-weight="650">${escapeXml(label.mark.name)}</text>
</g>`).join('\n')
  const markerElements = markPositions.map(mark => `<g>
  <circle cx="${mark.x.toFixed(1)}" cy="${mark.y.toFixed(1)}" r="10" fill="#FFFFFF"/>
  <circle cx="${mark.x.toFixed(1)}" cy="${mark.y.toFixed(1)}" r="5.5" fill="#314A57"/>
</g>`).join('\n')

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
<rect width="${width}" height="${height}" fill="#EAF5F8"/>
${landPaths}
${coastPaths}
${leaders}
${labelElements}
${markerElements}
<g transform="translate(${width - 66} 48)" fill="#183746" stroke="#183746">
  <text x="0" y="0" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" font-size="28" font-weight="700" stroke="none">N</text>
  <path d="M0 12 L-9 34 L0 29 L9 34 Z" stroke-width="2"/>
</g>
<rect x="0" y="${height - 36}" width="${width}" height="36" fill="#FFFFFF" fill-opacity=".84"/>
<text x="12" y="${height - 11}" fill="#455A64" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" font-size="19">${escapeXml(coastline.attribution)} · Not for navigation</text>
</svg>`

  const hotspots = markPositions.map(mark => {
    const label = labels.find(item => item.mark.id === mark.id)
    return {
      markId: mark.id,
      x: Number((mark.x / width).toFixed(6)),
      y: Number((mark.y / height).toFixed(6)),
      labelLeft: Number((label.rect.left / width).toFixed(6)),
      labelTop: Number((label.rect.top / height).toFixed(6)),
      labelRight: Number((label.rect.right / width).toFixed(6)),
      labelBottom: Number((label.rect.bottom / height).toFixed(6)),
    }
  })
  const outputUrl = new URL(imageName, resourceDirectory)
  const hotspotsUrl = new URL(hotspotsName, resourceDirectory)
  const temporarySvgUrl = new URL(`./.${imageName}.generated.svg`, import.meta.url)
  await writeFile(temporarySvgUrl, svg)
  await writeFile(hotspotsUrl, `${JSON.stringify(hotspots, null, 2)}\n`)
  try {
    execFileSync('rsvg-convert', [temporarySvgUrl.pathname, '--output', outputUrl.pathname, '--width', String(width), '--height', String(height)])
  } finally {
    await unlink(temporarySvgUrl).catch(() => {})
  }
  console.log(`Wrote ${outputUrl.pathname}`)
  console.log(`Wrote ${hotspots.length} hotspots to ${hotspotsUrl.pathname}`)
}

for (const [index, view] of pack.definition.navigation.quickBearingMapViews.entries()) {
  const fitMarkIds = new Set(view.fitMarkIds ?? projectedMarks.map(mark => mark.id))
  const viewMarks = projectedMarks.filter(mark => fitMarkIds.has(mark.id))
  await renderMap(
    index === 0 ? 'mark-locations.png' : `mark-locations-${view.id}.png`,
    index === 0 ? 'mark-location-hotspots.json' : `mark-location-${view.id}-hotspots.json`,
    viewMarks,
    view.fitMarkIds ? viewMarks : projectedMarks,
  )
}
