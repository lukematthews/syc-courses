#!/usr/bin/env node

/**
 * Standalone laid-mark course graphic generator.
 *
 * Example (Course 89, split after row 3 / Gate):
 *   node scripts/generate_laid_course_graphic.mjs \
 *     --input src/generated/course-pack/laid-courses.json \
 *     --course 89 \
 *     --break-after 3 \
 *     --marks 1,2,4,Gate \
 *     --output /tmp/course-89
 *
 * Produces /tmp/course-89.svg and /tmp/course-89.png. This script does not
 * alter course packs or generated app resources.
 */

import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, extname, resolve } from 'node:path'
import { mkdirSync } from 'node:fs'

const BASE_WIDTH = 840
const BASE_HEIGHT = 841
const ROW_HEIGHT = BASE_HEIGHT
const MAX_COLUMNS = 3
const TRACK_WIDTH = 4
const MARK_RADIUS = 5
const ROUNDING_RADIUS = 20
const FONT_SIZE = 29
const BLACK = '#000000'

const DEFAULT_ROLES = Object.freeze({
  '1': 'windward',
  '2': 'offset',
  '3': 'leeward',
  '4': 'inner-windward',
  '5': 'wing',
  Gate: 'gate',
})

function usage(message) {
  if (message) console.error(`Error: ${message}\n`)
  console.error(`Usage:
  node scripts/generate_laid_course_graphic.mjs \\
    --input <laid-courses.json> \\
    --course <number> \\
    [--break-after <row-index[,row-index...]>] \\
    [--marks <name[,name...]>] \\
    [--roles <roles.json>] \\
    [--output <path-without-extension>] \\
    [--rounding port|starboard] \\
    [--line-angle <degrees>] \\
    [--svg-only]

Notes:
  • Row indexes are zero-based. A boundary row ends one pass and starts the next.
  • A row with diagramBreakAfter: true is also treated as a pass boundary.
  • --marks supplies physical/context marks that are not present in the route.
  • The default SYC roles are 1=windward, 2=offset, 3=leeward,
    4=inner-windward, 5=wing, Gate=gate.
  • PNG generation requires rsvg-convert.`)
  process.exit(message ? 1 : 0)
}

function parseArgs(argv) {
  const args = {}
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index]
    if (token === '--help' || token === '-h') usage()
    if (token === '--svg-only') {
      args.svgOnly = true
      continue
    }
    if (!token.startsWith('--')) usage(`Unknown argument: ${token}`)
    const value = argv[index + 1]
    if (!value || value.startsWith('--')) usage(`Missing value for ${token}`)
    args[token.slice(2)] = value
    index += 1
  }
  if (!args.input) usage('--input is required')
  if (!args.course) usage('--course is required')
  return args
}

function normalize(value) {
  return String(value ?? '').trim().replace(/\s+/g, ' ')
}

function escapeXml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;')
}

function number(value, fallback) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : fallback
}

function point(x, y) {
  return { x, y }
}

function add(a, b) {
  return point(a.x + b.x, a.y + b.y)
}

function subtract(a, b) {
  return point(a.x - b.x, a.y - b.y)
}

function multiply(a, scale) {
  return point(a.x * scale, a.y * scale)
}

function length(vector) {
  return Math.hypot(vector.x, vector.y)
}

function unit(vector) {
  const magnitude = length(vector)
  return magnitude > 0 ? multiply(vector, 1 / magnitude) : point(0, 0)
}

function midpoint(a, b) {
  return point((a.x + b.x) / 2, (a.y + b.y) / 2)
}

function rotateAround(value, centre, radians) {
  const x = value.x - centre.x
  const y = value.y - centre.y
  return point(
    centre.x + x * Math.cos(radians) - y * Math.sin(radians),
    centre.y + x * Math.sin(radians) + y * Math.cos(radians),
  )
}

function format(value) {
  return Number(value.toFixed(2))
}

function loadRoles(path) {
  if (!path) return { ...DEFAULT_ROLES }
  return { ...DEFAULT_ROLES, ...JSON.parse(readFileSync(resolve(path), 'utf8')) }
}

function roleForRow(row, roles) {
  const name = normalize(row.mark)
  if (/^start$/i.test(name)) return 'start'
  if (/^finish$/i.test(name)) return 'finish'
  const direct = roles[name] ?? roles[Object.keys(roles).find(key => key.toLowerCase() === name.toLowerCase())]
  if (!direct) throw new Error(`No diagram role is defined for mark "${name}"`)
  return direct
}

function courseRounding(course, override) {
  if (override) return override
  const sides = course.rows
    .map(row => normalize(row.side).toLowerCase())
    .filter(side => side === 'port' || side === 'starboard')
  return sides.includes('starboard') && !sides.includes('port') ? 'starboard' : 'port'
}

function splitPasses(rows, cliBreaks) {
  const breaks = new Set(cliBreaks)
  rows.forEach((row, index) => {
    if (row.diagramBreakAfter === true) breaks.add(index)
  })
  const invalid = [...breaks].filter(index => index <= 0 || index >= rows.length - 1)
  if (invalid.length) throw new Error(`Pass breaks must be between route rows: ${invalid.join(', ')}`)
  const sorted = [...breaks].sort((a, b) => a - b)
  const passes = []
  let start = 0
  for (const end of sorted) {
    passes.push(rows.slice(start, end + 1))
    start = end
  }
  passes.push(rows.slice(start))
  return passes
}

function physicalMarks(rows, roles, explicitNames = []) {
  const result = new Map()
  const sources = [
    ...rows.map(row => ({ name: normalize(row.mark), row })),
    ...explicitNames.map(name => ({ name: normalize(name), row: { mark: normalize(name) } })),
  ]
  for (const source of sources) {
    const role = roleForRow(source.row, roles)
    if (role === 'start' || role === 'finish') continue
    const name = source.name
    if (!result.has(name)) result.set(name, { name, role })
  }
  return [...result.values()]
}

function panelLayout(panel, rounding) {
  const { left, top, width, height } = panel
  const centreX = left + width / 2
  const scale = Math.min(1, width / 420)
  const mapY = value => top + (panel.compact ? 82 + value * 0.89 : value)
  const topY = mapY(76)
  const bottomY = mapY(681)
  const side = rounding === 'port' ? -1 : 1
  const windwardX = centreX - 12 * scale
  const spread = 50 * scale
  const positions = {
    windward: point(windwardX, topY),
    offset: point(windwardX + side * spread, topY + 16),
    'inner-windward': point(windwardX, mapY(200)),
    leeward: point(centreX - 64 * scale, bottomY),
    wing: point(centreX + side * 72 * scale, mapY(390)),
    gate: point(centreX - 64 * scale, bottomY),
  }
  const lineHalf = 154 * scale
  const lineY = mapY(748)
  const boatX = centreX + 24 * scale
  positions.start = point(centreX, lineY)
  positions.finish = point(centreX, lineY)
  return { positions, centreX, lineY, lineHalf, boatX, gateHalf: 29.5 * scale, scale }
}

function transformLayout(layout, angleDegrees) {
  if (!angleDegrees) return layout
  const radians = angleDegrees * Math.PI / 180
  const centre = point(layout.centreX, layout.lineY)
  const positions = Object.fromEntries(
    Object.entries(layout.positions).map(([key, value]) => [key, rotateAround(value, centre, radians)]),
  )
  return { ...layout, positions, angleDegrees }
}

function markPosition(mark, layout) {
  const base = layout.positions[mark.role]
  if (!base) throw new Error(`No layout position exists for role "${mark.role}"`)
  return base
}

function gateMarkPositions(layout) {
  const centre = layout.positions.gate
  return [point(centre.x - layout.gateHalf, centre.y), point(centre.x + layout.gateHalf, centre.y)]
}

function routePoint(row, layout, roles) {
  const role = roleForRow(row, roles)
  return { name: normalize(row.mark), role, rounding: normalize(row.side).toLowerCase(), scale: layout.scale, ...layout.positions[role] }
}

function adjustedLineEndpoint(lineStart, lineEnd, target, preferBoat) {
  const middle = midpoint(lineStart, lineEnd)
  const candidates = [middle]
  const direction = unit(subtract(lineEnd, lineStart))
  for (const distance of [18, 36, 54, 72]) {
    const sign = preferBoat === 'end' ? 1 : -1
    candidates.push(add(middle, multiply(direction, distance * sign)))
  }
  // Prefer a point whose first leg does not run along the start/finish line.
  return candidates.find(candidate => Math.abs(unit(subtract(target, candidate)).y) > 0.2) ?? middle
}

function courseLineGeometry(layout, kind) {
  const radians = (layout.angleDegrees || 0) * Math.PI / 180
  const left = rotateAround(point(layout.centreX - layout.lineHalf, layout.lineY), point(layout.centreX, layout.lineY), radians)
  const right = rotateAround(point(layout.centreX + layout.lineHalf, layout.lineY), point(layout.centreX, layout.lineY), radians)
  const boat = rotateAround(point(layout.boatX, layout.lineY), point(layout.centreX, layout.lineY), radians)
  return { leftPin: left, rightPin: right, boat, lineStart: left, lineEnd: right, labelPin: kind === 'start' ? left : right }
}

function tangentArc(previous, current, next, rounding) {
  const radius = ROUNDING_RADIUS * (current.scale || 1)
  const incoming = unit(subtract(current, previous))
  const outgoing = unit(subtract(next, current))
  const side = rounding === 'starboard' ? -1 : 1
  const incomingNormal = point(-incoming.y * side, incoming.x * side)
  const outgoingNormal = point(-outgoing.y * side, outgoing.x * side)
  const before = add(current, multiply(incomingNormal, radius))
  const after = add(current, multiply(outgoingNormal, radius))
  const sweep = rounding === 'starboard' ? 1 : 0
  return { before, after, sweep, radius }
}

function continuousTrack(points) {
  if (points.length < 2) return { path: '', legs: [] }
  const commands = [`M ${format(points[0].x)} ${format(points[0].y)}`]
  const legSegments = []
  let cursor = points[0]
  for (let index = 1; index < points.length - 1; index += 1) {
    const current = points[index]
    if (current.role === 'gate') {
      commands.push(`L ${format(current.x)} ${format(current.y)}`)
      legSegments.push([cursor, current])
      cursor = current
      continue
    }
    const arc = tangentArc(points[index - 1], current, points[index + 1], current.rounding)
    commands.push(`L ${format(arc.before.x)} ${format(arc.before.y)}`)
    commands.push(`A ${format(arc.radius)} ${format(arc.radius)} 0 0 ${arc.sweep} ${format(arc.after.x)} ${format(arc.after.y)}`)
    legSegments.push([cursor, arc.before])
    cursor = arc.after
  }
  const end = points.at(-1)
  commands.push(`L ${format(end.x)} ${format(end.y)}`)
  legSegments.push([cursor, end])
  return { path: commands.join(' '), legs: legSegments }
}

function returnLoopTrack(points, rounding) {
  if (points.length !== 3 || points.at(-1).role !== 'finish') return null
  const [start, mark, finish] = points
  if (start.y < mark.y + 250 || finish.y < mark.y + 250) return null
  const side = rounding === 'port' ? 1 : -1
  const radius = ROUNDING_RADIUS * (mark.scale || 1)
  const before = point(mark.x + side * radius, mark.y)
  const after = point(mark.x - side * radius, mark.y)
  // As in the published Course 89 diagram, the continuation out of the Gate
  // is implicit. Starting the visible upwind lane above the Gate avoids an
  // unavoidable crossing with the straight windward-to-finish return leg.
  const visibleStart = point(before.x + side * 32 * (mark.scale || 1), start.y - 152 * (mark.scale || 1))
  const sweep = rounding === 'port' ? 0 : 1
  return {
    path: `M ${format(visibleStart.x)} ${format(visibleStart.y)} L ${format(before.x)} ${format(before.y)} A ${format(radius)} ${format(radius)} 0 0 ${sweep} ${format(after.x)} ${format(after.y)} L ${format(finish.x)} ${format(finish.y)}`,
    legs: [[visibleStart, before], [after, finish]],
  }
}

function arrowPolygon(from, to, at = 0.5, size = 9) {
  const direction = unit(subtract(to, from))
  if (!direction.x && !direction.y) return ''
  const centre = add(from, multiply(subtract(to, from), at))
  const perpendicular = point(-direction.y, direction.x)
  const tip = add(centre, multiply(direction, size))
  const rear = add(centre, multiply(direction, -size * 0.75))
  const a = add(rear, multiply(perpendicular, size * 0.65))
  const b = add(rear, multiply(perpendicular, -size * 0.65))
  return `<path class="direction-arrow" d="M ${format(tip.x)} ${format(tip.y)} L ${format(a.x)} ${format(a.y)} L ${format(b.x)} ${format(b.y)} Z"/>`
}

function gateFork(layout, incoming) {
  const centre = layout.positions.gate
  const [port, starboard] = gateMarkPositions(layout)
  const radius = ROUNDING_RADIUS * layout.scale
  const lowerY = centre.y + radius + 8 * layout.scale
  const trackStyle = `style="stroke-width:${format(TRACK_WIDTH * layout.scale)}"`
  const stem = incoming ? `<path class="course-track" ${trackStyle} d="M ${format(incoming.x)} ${format(incoming.y)} L ${format(centre.x)} ${format(centre.y)}"/>` : ''
  const leftEnd = point(port.x - radius, port.y)
  const rightEnd = point(starboard.x + radius, starboard.y)
  const leftPath = `<path class="course-track" ${trackStyle} d="M ${format(centre.x)} ${format(centre.y)} C ${format(centre.x - 10 * layout.scale)} ${format(lowerY)} ${format(port.x)} ${format(lowerY)} ${format(leftEnd.x)} ${format(port.y)}"/>`
  const rightPath = `<path class="course-track" ${trackStyle} d="M ${format(centre.x)} ${format(centre.y)} C ${format(centre.x + 10 * layout.scale)} ${format(lowerY)} ${format(starboard.x)} ${format(lowerY)} ${format(rightEnd.x)} ${format(starboard.y)}"/>`
  const leftTangent = point(port.x, lowerY)
  const rightTangent = point(starboard.x, lowerY)
  return `${stem}${leftPath}${rightPath}${arrowPolygon(leftTangent, leftEnd, 0.82, 7 * layout.scale)}${arrowPolygon(rightTangent, rightEnd, 0.82, 7 * layout.scale)}`
}

function renderBoat(position, angleDegrees = 0) {
  // Three anchors: square stern corners and bow. Quadratic sides meet at bow.
  const path = 'M -7.5 20 L 7.5 20 Q 7.5 -10 0 -20 Q -7.5 -10 -7.5 20 Z'
  const scale = position.scale || 1
  return `<path class="boat" d="${path}" transform="translate(${format(position.x)} ${format(position.y)}) rotate(${format(angleDegrees)}) scale(${format(scale)})"/>`
}

function labelCandidates(position, scale = 1) {
  return [
    { x: position.x, y: position.y + 31 * scale, anchor: 'middle', box: { x: position.x - 35 * scale, y: position.y + 10 * scale, width: 70 * scale, height: 28 * scale } },
    { x: position.x + 30 * scale, y: position.y + 9 * scale, anchor: 'start', box: { x: position.x + 23 * scale, y: position.y - 12 * scale, width: 70 * scale, height: 28 * scale } },
    { x: position.x - 30 * scale, y: position.y + 9 * scale, anchor: 'end', box: { x: position.x - 93 * scale, y: position.y - 12 * scale, width: 70 * scale, height: 28 * scale } },
    { x: position.x, y: position.y - 24 * scale, anchor: 'middle', box: { x: position.x - 35 * scale, y: position.y - 47 * scale, width: 70 * scale, height: 28 * scale } },
  ]
}

function boxesOverlap(a, b, padding = 3) {
  return a.x < b.x + b.width + padding && a.x + a.width + padding > b.x && a.y < b.y + b.height + padding && a.y + a.height + padding > b.y
}

function segmentIntersectsBox(from, to, box, padding = 5) {
  const left = box.x - padding
  const right = box.x + box.width + padding
  const top = box.y - padding
  const bottom = box.y + box.height + padding
  const steps = Math.max(2, Math.ceil(length(subtract(to, from)) / 8))
  for (let step = 0; step <= steps; step += 1) {
    const sample = add(from, multiply(subtract(to, from), step / steps))
    if (sample.x >= left && sample.x <= right && sample.y >= top && sample.y <= bottom) return true
  }
  return false
}

function renderMarks(marks, layout, routeSegments) {
  const scale = layout.scale
  const markRadius = MARK_RADIUS * scale
  const occupied = marks.flatMap(mark => {
    const position = markPosition(mark, layout)
    const points = mark.role === 'gate' ? gateMarkPositions(layout) : [position]
    return points.map(value => ({ x: value.x - markRadius - 3 * scale, y: value.y - markRadius - 3 * scale, width: markRadius * 2 + 6 * scale, height: markRadius * 2 + 6 * scale }))
  })
  occupied.push({ x: 374, y: 0, width: 92, height: 125 })
  const output = []
  for (const mark of marks) {
    const position = markPosition(mark, layout)
    if (mark.role === 'gate') {
      const [left, right] = gateMarkPositions(layout)
      output.push(`<circle class="mark" cx="${format(left.x)}" cy="${format(left.y)}" r="${format(markRadius)}"/>`)
      output.push(`<circle class="mark" cx="${format(right.x)}" cy="${format(right.y)}" r="${format(markRadius)}"/>`)
    } else {
      output.push(`<circle class="mark" cx="${format(position.x)}" cy="${format(position.y)}" r="${format(markRadius)}"/>`)
    }
    const candidates = mark.role === 'gate'
      ? [
          { x: position.x, y: position.y + 59 * scale, anchor: 'middle', box: { x: position.x - 35 * scale, y: position.y + 36 * scale, width: 70 * scale, height: 28 * scale } },
          { x: position.x + 76 * scale, y: position.y + 9 * scale, anchor: 'start', box: { x: position.x + 69 * scale, y: position.y - 12 * scale, width: 70 * scale, height: 28 * scale } },
          { x: position.x - 76 * scale, y: position.y + 9 * scale, anchor: 'end', box: { x: position.x - 139 * scale, y: position.y - 12 * scale, width: 70 * scale, height: 28 * scale } },
          { x: position.x, y: position.y - 24 * scale, anchor: 'middle', box: { x: position.x - 35 * scale, y: position.y - 47 * scale, width: 70 * scale, height: 28 * scale } },
        ]
      : labelCandidates(position, scale)
    const selected = candidates.find(candidate =>
      !occupied.some(box => boxesOverlap(candidate.box, box)) &&
      !routeSegments.some(([from, to]) => segmentIntersectsBox(from, to, candidate.box))
    ) ?? candidates[0]
    occupied.push(selected.box)
    output.push(`<text class="mark-label" style="font-size:${format(FONT_SIZE * scale)}px" x="${format(selected.x)}" y="${format(selected.y)}" text-anchor="${selected.anchor}">${escapeXml(mark.name)}</text>`)
  }
  return output.join('')
}

function renderLine(kind, layout) {
  const geometry = courseLineGeometry(layout, kind)
  const angle = layout.angleDegrees || 0
  const scale = layout.scale
  const boat = { ...geometry.boat, scale }
  return `<g class="${kind}-line"><path class="line-dash" style="stroke-width:${format(2 * scale)};stroke-dasharray:${format(3 * scale)} ${format(7 * scale)}" d="M ${format(geometry.lineStart.x)} ${format(geometry.lineStart.y)} L ${format(geometry.lineEnd.x)} ${format(geometry.lineEnd.y)}"/><circle class="mark" cx="${format(geometry.leftPin.x)}" cy="${format(geometry.leftPin.y)}" r="${format(MARK_RADIUS * scale)}"/><circle class="mark" cx="${format(geometry.rightPin.x)}" cy="${format(geometry.rightPin.y)}" r="${format(MARK_RADIUS * scale)}"/>${renderBoat(boat, angle)}<text class="line-label" style="font-size:${format(FONT_SIZE * scale)}px" x="${format(geometry.labelPin.x)}" y="${format(geometry.labelPin.y + 42 * scale)}" text-anchor="middle">${kind === 'start' ? 'Start' : 'Finish'}</text></g>`
}

function panelFor(index, total, rows) {
  const columns = Math.min(MAX_COLUMNS, total)
  const row = Math.floor(index / MAX_COLUMNS)
  const itemsInRow = Math.min(MAX_COLUMNS, total - row * MAX_COLUMNS)
  const panelWidth = BASE_WIDTH / columns
  const rowOffset = (columns - itemsInRow) * panelWidth / 2
  const column = index % MAX_COLUMNS
  return {
    left: rowOffset + column * panelWidth,
    top: row * ROW_HEIGHT,
    width: panelWidth,
    height: ROW_HEIGHT,
    row,
    rows,
    compact: columns === MAX_COLUMNS,
  }
}

function renderPass(passRows, panel, allMarks, roles, rounding, lineAngle) {
  const layout = transformLayout(panelLayout(panel, rounding), lineAngle)
  const route = passRows.map(row => routePoint(row, layout, roles))
  const hasStart = route[0]?.role === 'start'
  const hasFinish = route.at(-1)?.role === 'finish'
  if (hasStart && route.length > 1) {
    const line = courseLineGeometry(layout, 'start')
    const start = adjustedLineEndpoint(line.lineStart, line.lineEnd, route[1], 'end')
    route[0] = { ...route[0], ...start }
  }
  if (hasFinish && route.length > 1) {
    const line = courseLineGeometry(layout, 'finish')
    let crossing = adjustedLineEndpoint(line.lineStart, line.lineEnd, route.at(-2), 'start')
    if (route.at(-2).y < crossing.y - 150) {
      crossing = add(crossing, multiply(unit(subtract(line.lineEnd, line.lineStart)), Math.min(60, layout.lineHalf * 0.55)))
    }
    const travel = unit(subtract(crossing, route.at(-2)))
    route[route.length - 1] = { ...route.at(-1), ...add(crossing, multiply(travel, 24)) }
  }

  const gateIndex = route.at(-1)?.role === 'gate' ? route.length - 1 : -1
  const drawableRoute = route
  const { path, legs } = returnLoopTrack(drawableRoute, rounding) ?? continuousTrack(drawableRoute)
  const arrows = legs.map(([from, to]) => arrowPolygon(from, to, 0.5, 9 * layout.scale)).join('')
  let gate = ''
  if (gateIndex >= 0) gate = gateFork(layout, null)
  const lines = `${hasStart ? renderLine('start', layout) : ''}${hasFinish ? renderLine('finish', layout) : ''}`
  return `<g class="course-pass" id="pass-${panel.row}-${format(panel.left)}">${lines}<path class="course-track" style="stroke-width:${format(TRACK_WIDTH * layout.scale)}" d="${path}"/>${arrows}${gate}${renderMarks(allMarks, layout, legs)}</g>`
}

function renderSvg(course, passes, roles, rounding, lineAngle, explicitMarks) {
  const rowCount = Math.ceil(passes.length / MAX_COLUMNS)
  const height = rowCount * ROW_HEIGHT
  const allMarks = physicalMarks(course.rows, roles, explicitMarks)
  const panels = passes.map((pass, index) => renderPass(pass, panelFor(index, passes.length, rowCount), allMarks, roles, rounding, lineAngle)).join('\n')
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${BASE_WIDTH}" height="${height}" viewBox="0 0 ${BASE_WIDTH} ${height}">
  <title>Course ${escapeXml(course.courseNumber)} laid-mark diagram</title>
  <desc>Generated from ${escapeXml(course.route || course.rows.map(row => row.mark).join(' - '))}</desc>
  <style>
    .course-track { fill: none; stroke: ${BLACK}; stroke-width: ${TRACK_WIDTH}; stroke-linecap: round; stroke-linejoin: round; }
    .direction-arrow, .mark, .boat { fill: ${BLACK}; }
    .line-dash { fill: none; stroke: ${BLACK}; stroke-width: 2; stroke-dasharray: 3 7; stroke-linecap: round; }
    .mark-label, .line-label { fill: ${BLACK}; font: ${FONT_SIZE}px Arial, Helvetica, sans-serif; }
  </style>
  <rect width="${BASE_WIDTH}" height="${height}" fill="#fff"/>
  ${panels}
  <g id="wind"><text x="420" y="37" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="32">Wind</text><path d="M409 48h22v38h15l-26 28-26-28h15z" fill="${BLACK}"/></g>
</svg>`
}

const args = parseArgs(process.argv.slice(2))
const inputPath = resolve(args.input)
const courses = JSON.parse(readFileSync(inputPath, 'utf8'))
if (!Array.isArray(courses)) throw new Error(`Expected an array in ${inputPath}`)
const requestedNumber = String(args.course)
const course = courses.find(item => String(item.courseNumber) === requestedNumber)
if (!course) throw new Error(`Course ${requestedNumber} was not found in ${inputPath}`)
if (!Array.isArray(course.rows) || course.rows.length < 2) throw new Error(`Course ${requestedNumber} has no usable route rows`)

const roles = loadRoles(args.roles)
const cliBreaks = normalize(args['break-after'])
  ? normalize(args['break-after']).split(',').map(value => number(value, NaN))
  : []
if (cliBreaks.some(value => !Number.isInteger(value))) throw new Error('--break-after must contain zero-based integer row indexes')
const passes = splitPasses(course.rows, cliBreaks)
const rounding = courseRounding(course, args.rounding)
if (!['port', 'starboard'].includes(rounding)) throw new Error('--rounding must be port or starboard')
const lineAngle = number(args['line-angle'], 0)
const explicitMarks = normalize(args.marks) ? normalize(args.marks).split(',').map(normalize).filter(Boolean) : []
const outputBase = resolve(args.output || `course-${requestedNumber}-laid-generated`)
const svgPath = extname(outputBase) ? outputBase.replace(/\.(svg|png)$/i, '') + '.svg' : `${outputBase}.svg`
const pngPath = svgPath.replace(/\.svg$/i, '.png')
mkdirSync(dirname(svgPath), { recursive: true })
const svg = renderSvg(course, passes, roles, rounding, lineAngle, explicitMarks)
writeFileSync(svgPath, svg)

if (!args.svgOnly) {
  try {
    execFileSync('rsvg-convert', [svgPath, '--output', pngPath, '--width', String(BASE_WIDTH)], { stdio: 'pipe' })
  } catch (error) {
    if (error.code === 'ENOENT') throw new Error('rsvg-convert is required for PNG output; install librsvg or use --svg-only')
    throw error
  }
}

console.log(JSON.stringify({
  courseNumber: course.courseNumber,
  passes: passes.length,
  rounding,
  svg: svgPath,
  png: args.svgOnly ? null : pngPath,
}, null, 2))
