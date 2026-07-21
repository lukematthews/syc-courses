import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const WIDTH = 1215
const HEIGHT = 1680
const HEADER = 150
const FOOTER = 62
const semiMajorAxis = 6_378_137
const inverseFlattening = 298.257223563
const centralMeridianDegrees = 147
const scaleFactor = 0.9996
const falseEasting = 500_000
const falseNorthing = 10_000_000

export function generateMissingCourseCharts(pack, root) {
  const coastline = JSON.parse(readFileSync(join(root, 'android/app/src/main/assets/port-phillip-coastline.json'), 'utf8'))
  const markLookup = makeMarkLookup(pack.marks)
  let generated = 0
  for (const course of pack.fixedCourses) {
    const filename = course.chartImage.split('/').at(-1)
    if (!filename?.startsWith('generated-course-')) continue
    const pngPath = join(pack.chartDirectory, filename)
    const svgPath = pngPath.replace(/\.png$/, '.svg')
    const route = classifyRoute(course.rows, markLookup)
    const svg = route.unresolved.length === 0 && route.points.length >= 2 && route.points.length <= 28
      ? geographicChart(pack, course, route.points, coastline)
      : schematicChart(pack, course, route)
    writeFileSync(svgPath, svg)
    execFileSync('rsvg-convert', [svgPath, '--output', pngPath, '--width', String(WIDTH), '--height', String(HEIGHT)])
    generated += 1
  }
  let generatedLaid = 0
  for (const course of pack.laidCourses) {
    const filename = course.chartImage.split('/').at(-1)
    if (!filename?.startsWith('generated-course-')) continue
    const pngPath = join(pack.chartDirectory, filename)
    const svgPath = pngPath.replace(/\.png$/, '.svg')
    writeFileSync(svgPath, laidChart(pack, course))
    execFileSync('rsvg-convert', [svgPath, '--output', pngPath, '--width', String(WIDTH), '--height', String(HEIGHT)])
    generatedLaid += 1
  }
  if (generated) console.log(`Generated ${generated} missing fixed-course charts for ${pack.definition.shortName}`)
  if (generatedLaid) console.log(`Generated ${generatedLaid} laid-course charts for ${pack.definition.shortName}`)
}

function normalize(value) {
  return String(value)
    .replace(/\s*\([^)]*\)/g, '')
    .replace(/[\*¥]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase()
}

function makeMarkLookup(marks) {
  const lookup = new Map()
  for (const mark of marks) {
    for (const name of [mark.name, ...mark.aliases]) lookup.set(normalize(name), mark)
  }
  return lookup
}

function isDynamic(name) {
  return /^(start|finish|gate|turning mark|course published|special course|start at |finish at |cut outer pile)/i.test(name)
}

function classifyRoute(rows, lookup) {
  const points = []
  const unresolved = []
  for (const row of rows) {
    if (isDynamic(row.mark)) continue
    const mark = lookup.get(normalize(row.mark))
    if (mark) points.push({ mark, side: row.side })
    else unresolved.push(row.mark)
  }
  return { points, unresolved: [...new Set(unresolved)] }
}

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
      longitudeTerm + (1 - tangentSquared + curvature) * longitudeTerm ** 3 / 6
        + (5 - 18 * tangentSquared + tangentSquared ** 2 + 72 * curvature - 58 * secondEccentricitySquared) * longitudeTerm ** 5 / 120
    ),
    northing: falseNorthing + scaleFactor * (meridionalArc + radius * tangent * (
      longitudeTerm ** 2 / 2 + (5 - tangentSquared + 9 * curvature + 4 * curvature ** 2) * longitudeTerm ** 4 / 24
        + (61 - 58 * tangentSquared + tangentSquared ** 2 + 600 * curvature - 330 * secondEccentricitySquared) * longitudeTerm ** 6 / 720
    )),
  }
}

function geographicChart(pack, course, route, coastline) {
  const projected = route.map(point => ({ ...point, projected: project(point.mark.latitude, point.mark.longitude) }))
  const unique = [...new Map(projected.map(point => [point.mark.id, point])).values()]
  const minE = Math.min(...projected.map(point => point.projected.easting))
  const maxE = Math.max(...projected.map(point => point.projected.easting))
  const minN = Math.min(...projected.map(point => point.projected.northing))
  const maxN = Math.max(...projected.map(point => point.projected.northing))
  const centreE = (minE + maxE) / 2
  const centreN = (minN + maxN) / 2
  let spanE = Math.max(maxE - minE, 2600) * 1.42
  let spanN = Math.max(maxN - minN, 2600) * 1.42
  const contentAspect = WIDTH / (HEIGHT - HEADER - FOOTER)
  if (spanE / spanN < contentAspect) spanE = spanN * contentAspect
  else spanN = spanE / contentAspect
  const viewport = { left: centreE - spanE / 2, right: centreE + spanE / 2, bottom: centreN - spanN / 2, top: centreN + spanN / 2 }
  const position = point => ({
    x: (point.easting - viewport.left) / spanE * WIDTH,
    y: HEADER + (viewport.top - point.northing) / spanN * (HEIGHT - HEADER - FOOTER),
  })
  const pathForLine = path => path.map(([longitude, latitude], index) => {
    const p = position(project(latitude, longitude))
    return `${index ? 'L' : 'M'}${p.x.toFixed(1)},${p.y.toFixed(1)}`
  }).join(' ')
  const pathForRing = ring => `${pathForLine(ring)} Z`
  const land = coastline.landPolygons.map(polygon => `<path d="${polygon.map(pathForRing).join(' ')}" fill="#F3E4A6" fill-rule="evenodd"/>`).join('\n')
  const coast = coastline.paths.map(path => `<path d="${pathForLine(path)}" fill="none" stroke="#58717D" stroke-width="2.2"/>`).join('\n')
  const routePositions = projected.map(point => ({ ...point, ...position(point.projected) }))
  const routePath = routePositions.map((point, index) => `${index ? 'L' : 'M'}${point.x.toFixed(1)},${point.y.toFixed(1)}`).join(' ')
  const arrows = directionArrows(routePositions, 'arrow-map', 8)
  const labels = unique.map((point, index) => {
    const p = position(point.projected)
    const right = p.x < WIDTH * .63
    const x = right ? p.x + 18 : p.x - 18
    const anchor = right ? 'start' : 'end'
    const y = p.y + (index % 2 ? 28 : -18)
    return `<g><circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="11" fill="#fff"/><circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="6.5" fill="#173D51"/><text x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="${anchor}" class="mark">${escapeXml(point.mark.name)}</text></g>`
  }).join('\n')
  return svgFrame(pack, course, `${land}\n${coast}\n<path d="${routePath}" fill="none" stroke="#D44A2A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>\n${arrows}\n${labels}`, 'Geographic course diagram from published pack coordinates')
}

function schematicChart(pack, course, route) {
  const rows = course.rows
  const columns = rows.length > 32 ? 6 : rows.length > 18 ? 5 : 4
  const usableWidth = WIDTH - 90
  const usableHeight = HEIGHT - HEADER - FOOTER - 90
  const columnWidth = usableWidth / columns
  const rowCount = Math.ceil(rows.length / columns)
  const rowHeight = usableHeight / Math.max(rowCount, 1)
  const positions = rows.map((row, index) => {
    const gridRow = Math.floor(index / columns)
    const offset = index % columns
    const gridColumn = gridRow % 2 ? columns - 1 - offset : offset
    return { row, x: 45 + columnWidth * (gridColumn + .5), y: HEADER + 50 + rowHeight * (gridRow + .5) }
  })
  const legs = positions.slice(1).map((point, index) => `<line x1="${positions[index].x.toFixed(1)}" y1="${positions[index].y.toFixed(1)}" x2="${point.x.toFixed(1)}" y2="${point.y.toFixed(1)}" stroke="#D44A2A" stroke-width="6"/>`).join('\n')
  const arrows = directionArrows(positions, 'arrow-flow', 6)
  const nodes = positions.map(({ row, x, y }) => {
    const side = sideLabel(row.side)
    const lines = wrapLabel(row.mark, 22)
    const labelY = side ? y - (lines.length - 1) * 12 - 7 : y - (lines.length - 1) * 12 + 7
    const label = lines.map((line, index) => `<tspan x="${x.toFixed(1)}" y="${(labelY + index * 24).toFixed(1)}">${escapeXml(line)}</tspan>`).join('')
    return `<g><rect x="${(x - columnWidth * .39).toFixed(1)}" y="${(y - Math.min(rowHeight * .3, 38)).toFixed(1)}" width="${(columnWidth * .78).toFixed(1)}" height="${Math.min(rowHeight * .6, 76).toFixed(1)}" rx="12" fill="#fff" stroke="#46636F" stroke-width="2"/><text text-anchor="middle" class="node">${label}</text>${side ? `<text x="${x.toFixed(1)}" y="${(y + 26).toFixed(1)}" text-anchor="middle" class="side">${side}</text>` : ''}</g>`
  }).join('\n')
  const unresolved = route.unresolved.length ? `Schematic used: coordinates unavailable for ${route.unresolved.map(escapeXml).join(', ')}` : 'Schematic used for route legibility'
  return svgFrame(pack, course, `${legs}\n${arrows}\n${nodes}`, unresolved)
}

function laidChart(pack, course) {
  const roles = laidMarkRoles(course)
  const positions = course.rows.map((row, index) => ({
    row,
    index,
    ...laidPosition(row, index, course, roles),
  }))
  const laps = splitLaidLaps(positions)
  const panels = laidLapPanels(laps, roles, pack.definition.shortName === 'BYS' && course.courseNumber === 10)
  const wind = `<g transform="translate(${WIDTH / 2} 190)"><text x="0" y="0" text-anchor="middle" class="wind">WIND</text><path d="M0 24 V85" stroke="#173D51" stroke-width="9" marker-end="url(#arrow-wind)"/></g>`
  const note = course.comparableCourseNote || 'Schematic laid-course geometry; mark positions and line locations are set on the water'
  return svgFrame(pack, course, `${wind}\n${panels}`, note)
}

function splitLaidLaps(positions) {
  const laps = []
  let lap = [positions[0]]
  for (let index = 1; index < positions.length; index += 1) {
    const point = positions[index]
    lap.push(point)
    if (point.role === 'leeward' || point.role === 'gate') {
      if (positions[index + 1]?.role === 'finish') {
        lap.push(positions[index + 1])
        index += 1
      }
      laps.push(lap)
      lap = [point]
    } else if (point.role === 'finish') {
      laps.push(lap)
      lap = []
    }
  }
  if (lap.length > 1) laps.push(lap)
  return laps
}

function laidLapPanels(laps, roles, useWideBysLoops) {
  const columns = laps.length >= 5 ? 3 : Math.min(2, laps.length)
  const rows = Math.ceil(laps.length / columns)
  const top = 245
  const availableHeight = HEIGHT - FOOTER - top - 20
  const panelWidth = WIDTH / columns
  const panelHeight = availableHeight / rows
  const scale = Math.min((panelWidth - 28) / 360, (panelHeight - 28) / 600)
  return laps.map((lap, index) => {
    const row = Math.floor(index / columns)
    const rowStart = row * columns
    const rowItems = Math.min(columns, laps.length - rowStart)
    const rowOffset = (columns - rowItems) * panelWidth / 2
    const column = index % columns
    const x = rowOffset + column * panelWidth + (panelWidth - 360 * scale) / 2
    const y = top + row * panelHeight + (panelHeight - 600 * scale) / 2
    return `<g transform="translate(${x.toFixed(1)} ${y.toFixed(1)}) scale(${scale.toFixed(4)})">${laidLap(lap, index, laps.length, roles, useWideBysLoops)}</g>`
  }).join('\n')
}

function laidLap(lap, index, total, roles, useWideBysLoops) {
  const local = lap.map(point => ({ ...point, ...laidLapPosition(point, roles) }))
  const trackPositions = offsetRepeatedTrackPoints(local)
  const track = useWideBysLoops ? wideBysCourse10Track(local) : continuousLaidTrack(trackPositions)
  const arrows = useWideBysLoops ? wideBysCourse10Arrows(local) : directionArrows(trackPositions, 'arrow-laid', 6)
  const marks = laidMarks(local, roles, useWideBysLoops)
  const lines = laidLapLines(local, roles)
  return `<text x="180" y="26" text-anchor="middle" class="lap-title">Lap ${index + 1} of ${total}</text>${lines}${track}${arrows}${marks}`
}

function wideBysCourse10Track(lap) {
  const hasStart = lap.some(point => point.role === 'start')
  const hasFinish = lap.some(point => point.role === 'finish')
  const hasOffset = lap.some(point => point.role === 'offset')
  let path
  if (hasOffset) {
    path = 'M160,535 L255,120 C255,48 190,42 185,112 C135,72 82,92 92,155 C96,181 118,194 145,184 L154,445 C154,500 206,500 206,445'
  } else {
    path = 'M206,445 L255,120 C255,48 185,48 185,120 L154,445 C154,500 206,500 206,445'
  }
  if (hasFinish) path += ' L200,535'
  return `<path d="${path}" fill="none" stroke="#D44A2A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>`
}

function wideBysCourse10Arrows(lap) {
  const hasOffset = lap.some(point => point.role === 'offset')
  const hasFinish = lap.some(point => point.role === 'finish')
  const arrow = (x1, y1, x2, y2) => `<line x1="${x1}" y1="${y1}" x2="${(x1 + x2) / 2}" y2="${(y1 + y2) / 2}" stroke="#D44A2A" stroke-width="6" stroke-linecap="round" marker-end="url(#arrow-laid)"/>`
  const arrows = [arrow(hasOffset ? 160 : 206, hasOffset ? 535 : 445, 255, 120)]
  if (hasOffset) {
    arrows.push(arrow(250, 72, 190, 85))
    arrows.push(arrow(102, 165, 154, 445))
  } else {
    arrows.push(arrow(250, 72, 190, 72))
    arrows.push(arrow(185, 120, 154, 445))
  }
  if (hasFinish) arrows.push(arrow(206, 445, 200, 535))
  return arrows.join('\n')
}

function laidLapPosition(point, roles) {
  if (point.role === 'start') return { role: point.role, x: 160, y: 535 }
  if (point.role === 'finish') return roles.upwindFinish
    ? { role: point.role, x: 220, y: 45 }
    : { role: point.role, x: 200, y: 535 }
  if (point.role === 'windward') return { role: point.role, x: 220, y: 105 }
  if (point.role === 'offset') return { role: point.role, x: 130, y: 135 }
  return { role: point.role, x: 180, y: 445 }
}

function laidLapLines(lap, roles) {
  const hasStart = lap.some(point => point.role === 'start')
  const hasFinish = lap.some(point => point.role === 'finish')
  const boat = (x, y) => `<path d="M${x - 15},${y + 16} L${x + 15},${y + 16} L${x + 11},${y - 14} L${x - 11},${y - 14} Z" fill="#fff" stroke="#173D51" stroke-width="3"/>`
  const mark = (x, y, fill) => `<circle cx="${x}" cy="${y}" r="12" fill="${fill}" stroke="#173D51" stroke-width="3"/>`
  let content = ''
  if (hasStart || (hasFinish && !roles.upwindFinish)) {
    content += `<line x1="40" y1="535" x2="320" y2="535" stroke="#173D51" stroke-width="3" stroke-dasharray="9 9"/>${boat(180, 535)}`
    if (hasStart) content += `${mark(40, 535, '#36A86B')}<text x="40" y="575" text-anchor="middle" class="lap-label">Start</text>`
    if (hasFinish) content += `${mark(320, 535, '#fff')}<text x="320" y="575" text-anchor="middle" class="lap-label">Finish</text>`
  }
  if (hasFinish && roles.upwindFinish) {
    content += `<line x1="80" y1="45" x2="320" y2="45" stroke="#173D51" stroke-width="3" stroke-dasharray="9 9"/>${mark(80, 45, '#fff')}${boat(320, 45)}<text x="200" y="82" text-anchor="middle" class="lap-label">Finish</text>`
  }
  return `<g>${content}</g>`
}

function laidMarkRoles(course) {
  const names = course.rows.map(row => normalize(row.mark))
  const firstOne = names.indexOf('1')
  const oneA = names.indexOf('1a')
  return {
    oneAIsOffset: firstOne >= 0 && oneA === firstOne + 1,
    upwindFinish: /upwind/i.test(`${course.route} ${course.comparableCourseNote || ''}`),
  }
}

function laidRole(row, roles) {
  const name = normalize(row.mark)
  const side = normalize(row.side)
  if (name.includes('start')) return 'start'
  if (name.includes('finish')) return 'finish'
  if (side.includes('gate') || name.includes('gate') || /p\/s$/.test(name)) return 'gate'
  if (name.includes('offset') || name === '2' || (name === '1a' && roles.oneAIsOffset)) return 'offset'
  if (/^(1|1a|1b|mark 1)$/.test(name)) return 'windward'
  if (/^(3|4)$/.test(name)) return 'leeward'
  return 'leeward'
}

function laidPosition(row, index, course, roles) {
  const role = laidRole(row, roles)
  if (role === 'start') return { role, x: 560, y: 1350 }
  if (role === 'finish') return roles.upwindFinish
    ? { role, x: 570, y: 215 }
    : { role, x: 640, y: 1350 }
  if (role === 'windward') return { role, x: 650, y: 340 }
  if (role === 'offset') return { role, x: 500, y: 400 }
  if (role === 'gate') return { role, x: 600, y: 1180 }
  return { role, x: 600, y: 1180 }
}

function simplifyLaidTrack(positions) {
  const simplified = [positions[0]]
  const seenEdges = new Set()
  for (let index = 1; index < positions.length - 1; index += 1) {
    const from = positions[index - 1]
    const to = positions[index]
    const edge = `${from.role}:${normalize(from.row.mark)}>${to.role}:${normalize(to.row.mark)}`
    if (seenEdges.has(edge)) break
    seenEdges.add(edge)
    simplified.push(to)
  }
  const terminal = positions.at(-2)
  if (terminal && simplified.at(-1) !== terminal) simplified.push(terminal)
  simplified.push(positions.at(-1))
  return simplified.filter((point, index, values) => index === 0 || point !== values[index - 1])
}

function offsetRepeatedTrackPoints(points) {
  const keyFor = point => `${point.role}:${normalize(point.row.mark)}`
  const totals = new Map()
  for (const point of points) totals.set(keyFor(point), (totals.get(keyFor(point)) || 0) + 1)
  const seen = new Map()
  return points.map(point => {
    const key = keyFor(point)
    const count = totals.get(key)
    if (count < 2 || point.role === 'start' || point.role === 'finish') return point
    const ordinal = seen.get(key) || 0
    seen.set(key, ordinal + 1)
    return { ...point, x: point.x + (ordinal - (count - 1) / 2) * 52 }
  })
}

function continuousLaidTrack(points) {
  const radius = 88
  if (points.length < 2) return ''
  const commands = [`M${points[0].x},${points[0].y}`]
  for (let index = 1; index < points.length - 1; index += 1) {
    const previous = points[index - 1]
    const point = points[index]
    const next = points[index + 1]
    const inLength = Math.hypot(point.x - previous.x, point.y - previous.y)
    const outLength = Math.hypot(next.x - point.x, next.y - point.y)
    const inRadius = Math.min(radius, inLength * .22)
    const outRadius = Math.min(radius, outLength * .22)
    const before = {
      x: point.x - (point.x - previous.x) / inLength * inRadius,
      y: point.y - (point.y - previous.y) / inLength * inRadius,
    }
    const after = {
      x: point.x + (next.x - point.x) / outLength * outRadius,
      y: point.y + (next.y - point.y) / outLength * outRadius,
    }
    commands.push(`L${before.x.toFixed(1)},${before.y.toFixed(1)} Q${point.x},${point.y} ${after.x.toFixed(1)},${after.y.toFixed(1)}`)
  }
  commands.push(`L${points.at(-1).x},${points.at(-1).y}`)
  return `<path d="${commands.join(' ')}" fill="none" stroke="#D44A2A" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>`
}

function laidLines(positions, roles) {
  const boat = (x, y) => `<path d="M${x - 19},${y + 20} L${x + 19},${y + 20} L${x + 13},${y - 18} L${x - 13},${y - 18} Z" fill="#fff" stroke="#173D51" stroke-width="3"/>`
  const mark = (x, y, fill) => `<circle cx="${x}" cy="${y}" r="15" fill="${fill}" stroke="#173D51" stroke-width="3"/>`
  if (!roles.upwindFinish) {
    return `<g><line x1="300" y1="1350" x2="900" y2="1350" stroke="#173D51" stroke-width="4" stroke-dasharray="12 12"/>${mark(300, 1350, '#36A86B')}${boat(600, 1350)}${mark(900, 1350, '#fff')}<text x="300" y="1410" text-anchor="middle" class="laid-label">Start</text><text x="900" y="1410" text-anchor="middle" class="laid-label">Finish</text></g>`
  }
  return `<g><line x1="300" y1="1350" x2="600" y2="1350" stroke="#173D51" stroke-width="4" stroke-dasharray="12 12"/>${mark(300, 1350, '#36A86B')}${boat(600, 1350)}<text x="300" y="1410" text-anchor="middle" class="laid-label">Start</text><line x1="420" y1="215" x2="720" y2="215" stroke="#173D51" stroke-width="4" stroke-dasharray="12 12"/>${mark(420, 215, '#fff')}${boat(720, 215)}<text x="570" y="275" text-anchor="middle" class="laid-label">Finish</text></g>`
}

function laidMarks(positions, roles, useWideBysLoops = false) {
  const unique = new Map()
  for (const point of positions) {
    const key = `${point.role}:${normalize(point.row.mark)}`
    if (!unique.has(key)) unique.set(key, point)
  }
  return [...unique.values()].map(point => {
    const label = escapeXml(point.row.mark)
    if (point.role === 'start' || point.role === 'finish') return ''
    if (point.role === 'gate') {
      return `<g><circle cx="${point.x - 65}" cy="${point.y}" r="17" fill="#F28A32" stroke="#173D51" stroke-width="3"/><circle cx="${point.x + 65}" cy="${point.y}" r="17" fill="#F28A32" stroke="#173D51" stroke-width="3"/><text x="${point.x}" y="${point.y + 58}" text-anchor="middle" class="laid-label">${label}</text></g>`
    }
    const fill = point.role === 'offset' ? '#F2D53C' : '#F28A32'
    const shape = point.role === 'offset'
      ? `<circle cx="${point.x}" cy="${point.y}" r="18" fill="${fill}" stroke="#173D51" stroke-width="3"/>`
      : `<path d="M${point.x},${point.y - 23} L${point.x + 22},${point.y + 19} L${point.x - 22},${point.y + 19} Z" fill="${fill}" stroke="#173D51" stroke-width="3"/>`
    let labelX = point.x + 32
    let labelY = point.y + 9
    let anchor = 'start'
    if (useWideBysLoops) {
      anchor = 'middle'
      if (point.role === 'windward') {
        labelX = point.x
        labelY = point.y + 54
      } else if (point.role === 'offset') {
        labelX = point.x
        labelY = point.y + 56
      } else {
        labelX = point.x - 48
        labelY = point.y + 8
      }
    }
    return `<g>${shape}<text x="${labelX}" y="${labelY}" text-anchor="${anchor}" class="laid-label">${label}</text></g>`
  }).join('\n')
}

function directionArrows(positions, marker, strokeWidth) {
  return positions.slice(1).map((point, index) => {
    const previous = positions[index]
    const midpoint = {
      x: (previous.x + point.x) / 2,
      y: (previous.y + point.y) / 2,
    }
    return `<line x1="${previous.x.toFixed(1)}" y1="${previous.y.toFixed(1)}" x2="${midpoint.x.toFixed(1)}" y2="${midpoint.y.toFixed(1)}" stroke="#D44A2A" stroke-width="${strokeWidth}" stroke-linecap="round" marker-end="url(#${marker})"/>`
  }).join('\n')
}

function svgFrame(pack, course, content, note) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
<defs><marker id="arrow-map" markerWidth="80" markerHeight="80" refX="72" refY="28" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L0,56 L76,28 z" fill="#D44A2A"/></marker><marker id="arrow-flow" markerWidth="72" markerHeight="72" refX="64" refY="24" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L0,48 L68,24 z" fill="#D44A2A"/></marker><marker id="arrow-laid" markerWidth="42" markerHeight="42" refX="38" refY="14" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L0,28 L40,14 z" fill="#D44A2A"/></marker><marker id="arrow-wind" markerWidth="48" markerHeight="48" refX="42" refY="16" orient="auto" markerUnits="userSpaceOnUse"><path d="M0,0 L0,32 L44,16 z" fill="#173D51"/></marker><style>.title{font:700 44px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51}.subtitle{font:500 25px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#45606D}.mark{font:700 27px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51;paint-order:stroke;stroke:#fff;stroke-width:8px;stroke-linejoin:round}.node{font:700 22px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51}.side{font:500 16px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#55707C}.laid-label{font:700 28px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51;paint-order:stroke;stroke:#EAF5F8;stroke-width:8px;stroke-linejoin:round}.lap-title{font:700 24px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51}.lap-label{font:700 20px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51}.wind{font:700 25px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#173D51;letter-spacing:2px}.footer{font:500 18px -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;fill:#465D67}</style></defs>
<rect width="${WIDTH}" height="${HEIGHT}" fill="#EAF5F8"/>
${content}
<rect width="${WIDTH}" height="${HEADER}" fill="#fff"/>
<text x="42" y="62" class="title">${escapeXml(pack.definition.shortName)} Course ${course.courseNumber}</text>
<text x="42" y="105" class="subtitle">${escapeXml(course.route || '')}${course.totalDistance ? ` · ${escapeXml(course.totalDistance)}` : ''}</text>
<rect y="${HEIGHT - FOOTER}" width="${WIDTH}" height="${FOOTER}" fill="#fff"/>
<text x="24" y="${HEIGHT - 34}" class="footer">Not for navigation · Official sailing instructions and race-day communications take precedence</text>
<text x="24" y="${HEIGHT - 11}" class="footer">${escapeXml(note)}</text>
</svg>\n`
}

function sideLabel(side) {
  if (side === 'start' || side === 'finish') return side.toUpperCase()
  if (side.includes('starboard')) return 'STARBOARD'
  if (side.includes('port')) return 'PORT'
  if (side.includes('gate')) return 'GATE'
  return side || ''
}

function wrapLabel(value, maxLength) {
  const words = String(value).trim().split(/\s+/)
  const lines = []
  for (const word of words) {
    const candidate = lines.length ? `${lines.at(-1)} ${word}` : word
    if (candidate.length <= maxLength) {
      if (lines.length) lines[lines.length - 1] = candidate
      else lines.push(candidate)
    } else if (lines.length < 2) {
      lines.push(word)
    } else {
      lines[1] = `${lines[1]}…`
      break
    }
  }
  return lines
}

function escapeXml(value) {
  return String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;')
}
