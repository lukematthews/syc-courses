import { writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { deflateRawSync } from 'node:zlib'

const output = join(dirname(fileURLToPath(import.meta.url)), 'syc-sailing-shapes.xml')
const black = '#101820'
const courseStrokeWidth = 4
const font = `fontColor=${black};fontSize=20;fontFamily=Helvetica;`

function model(cells) {
  return `<mxGraphModel dx="900" dy="620" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="0" pageScale="1" pageWidth="900" pageHeight="620" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>${cells.join('')}</root></mxGraphModel>`
}

function vertex(id, value, style, x, y, w, h, parent = '1') {
  return `<mxCell id="${id}" value="${value}" style="${style}" vertex="1" parent="${parent}"><mxGeometry x="${x}" y="${y}" width="${w}" height="${h}" as="geometry"/></mxCell>`
}

function edge(id, style, x1, y1, x2, y2, points = []) {
  const waypointXml = points.length ? `<Array as="points">${points.map(([x, y]) => `<mxPoint x="${x}" y="${y}"/>`).join('')}</Array>` : ''
  return `<mxCell id="${id}" value="" style="${style}" edge="1" parent="1"><mxGeometry relative="1" as="geometry"><mxPoint x="${x1}" y="${y1}" as="sourcePoint"/><mxPoint x="${x2}" y="${y2}" as="targetPoint"/>${waypointXml}</mxGeometry></mxCell>`
}

function connectedEdge(id, style, source, target) {
  return `<mxCell id="${id}" value="" style="${style}" edge="1" parent="1" source="${source}" target="${target}"><mxGeometry relative="1" as="geometry"/></mxCell>`
}

function text(id, value, x, y, w = 80, h = 30, size = 20) {
  return vertex(id, value, `text;html=1;strokeColor=none;fillColor=none;align=center;verticalAlign=middle;whiteSpace=wrap;rounded=0;${font}fontSize=${size};`, x, y, w, h)
}

function stencil(id, source, x, y, w, h) {
  const compressed = deflateRawSync(Buffer.from(encodeURIComponent(source))).toString('base64')
  return vertex(id, '', `shape=stencil(${compressed});whiteSpace=wrap;html=1;aspect=fixed;fillColor=${black};strokeColor=${black};strokeWidth=4;`, x, y, w, h)
}

function gateStencil() {
  return `<shape name="Constant-radius gate" h="100" w="140" aspect="fixed" strokewidth="inherit"><connections/><foreground><strokewidth width="4" fixed="1"/><ellipse x="28" y="18" w="20" h="20"/><fillstroke/><ellipse x="92" y="18" w="20" h="20"/><fillstroke/><path><move x="6" y="54"/><arc rx="32" ry="32" x-axis-rotation="0" large-arc-flag="0" sweep-flag="0" x="70" y="54"/></path><stroke/><path><move x="134" y="54"/><arc rx="32" ry="32" x-axis-rotation="0" large-arc-flag="0" sweep-flag="1" x="70" y="54"/></path><stroke/><path><move x="2" y="47"/><line x="11" y="54"/><line x="2" y="61"/><close/></path><fill/><path><move x="138" y="47"/><line x="129" y="54"/><line x="138" y="61"/><close/></path><fill/></foreground></shape>`
}

function markCells(label = '', x = 28, y = 8, id = 'mark') {
  const cells = [vertex(id, '', `ellipse;whiteSpace=wrap;html=1;aspect=fixed;fillColor=${black};strokeColor=${black};`, x, y, 24, 24)]
  if (label) cells.push(text(`${id}-label`, label, x - 28, y + 27, 80, 30))
  return cells
}

function boatStencil() {
  return `<shape name="Committee boat" h="100" w="54" aspect="fixed" strokewidth="inherit"><connections/><foreground><strokewidth width="2" fixed="1"/><path><move x="27" y="2"/><curve x1="58" y1="22" x2="54" y2="70" x3="46" y3="95"/><line x="8" y="95"/><curve x1="0" y1="70" x2="-4" y2="22" x3="27" y3="2"/><close/></path><fillstroke/></foreground></shape>`
}

function boatCells(x = 0, y = 0, id = 'boat', w = 54, h = 100) {
  return [stencil(id, boatStencil(), x, y, w, h)]
}

function lineCells(label, reversed = false) {
  const mark = markCells('', reversed ? 192 : 8, 25, 'line-mark')
  const boat = boatCells(reversed ? 8 : 160, 0, 'line-boat', 32, 60)
  const connectorStyle = `endArrow=none;startArrow=none;html=1;rounded=0;dashed=1;dashPattern=2 6;strokeWidth=2;strokeColor=${black};`
  return [
    ...mark, ...boat,
    connectedEdge('line', connectorStyle, reversed ? 'line-boat' : 'line-mark', reversed ? 'line-mark' : 'line-boat'),
    text('line-label', label, 72, 64, 80, 30),
  ]
}

function gateCells() {
  return [
    stencil('gate-stencil', gateStencil(), 0, 0, 140, 100),
    text('gate-label', 'Gate', 30, 94, 80, 30),
  ]
}

function roundingCells() {
  return [
    vertex('rounding-arc', '', `shape=mxgraph.basic.arc;startAngle=0.5;endAngle=1;fillColor=none;strokeColor=${black};strokeWidth=${courseStrokeWidth};aspect=fixed;rotation=90;`, 0, 0, 120, 120),
    ...markCells('', 48, 48, 'rounding-mark'),
    text('rounding-label', '4', 20, 74, 80, 28, 18),
  ]
}

function arrowCells(curved = false) {
  return [edge('course-arrow', `endArrow=classic;endFill=1;html=1;${curved ? 'curved=1;rounded=1;' : 'rounded=0;'}strokeWidth=${courseStrokeWidth};strokeColor=${black};`, 15, 90, 100, 12, curved ? [[18, 30], [62, 18]] : [])]
}

function windCells() {
  return [text('wind-label', 'Wind', 20, 0, 80, 30, 22), edge('wind-arrow', `endArrow=classic;endFill=1;html=1;rounded=0;strokeWidth=7;strokeColor=${black};`, 60, 35, 60, 90)]
}

function fragmentStartMarkGate() {
  return [
    ...lineCells('Start'),
    ...markCells('4', 100, 30, 'fragment-mark'),
    ...gateCells().map((cell) => cell.replaceAll('id="gate-', 'id="fragment-gate-').replaceAll('id="gate-label"', 'id="fragment-gate-label"')),
    edge('fragment-out', `endArrow=classic;endFill=1;html=1;curved=1;rounded=1;strokeWidth=${courseStrokeWidth};strokeColor=${black};`, 112, 180, 112, 45, [[100, 110]]),
    edge('fragment-back', `endArrow=classic;endFill=1;html=1;curved=1;rounded=1;strokeWidth=${courseStrokeWidth};strokeColor=${black};`, 112, 45, 112, 180, [[126, 110]]),
  ]
}

const entries = []
function add(title, tags, w, h, cells) { entries.push({ title, tags, w, h, xml: model(cells) }) }

add('Unlabelled mark', 'mark buoy laid course', 80, 48, markCells())
for (let number = 1; number <= 9; number++) add(`Mark ${number}`, `mark ${number} buoy laid course`, 80, 68, markCells(String(number)))
add('Gate', 'gate marks laid course', 140, 126, gateCells())
add('Committee boat', 'committee race boat vessel top down', 54, 100, boatCells())
add('Start line', 'start line committee boat pin', 224, 88, lineCells('Start'))
add('Finish line', 'finish line committee boat pin', 224, 88, lineCells('Finish', true))
add('Wind arrow', 'wind direction arrow', 120, 100, windCells())
add('Straight course arrow', 'course route direction arrow', 120, 110, arrowCells())
add('Curved course arrow', 'course route direction curved arrow', 120, 110, arrowCells(true))
add('Adjustable rounding arc', 'rounding mark circular semicircle adjustable angle handles course', 120, 120, roundingCells())

const json = JSON.stringify(entries)
writeFileSync(output, `<?xml version="1.0" encoding="UTF-8"?>\n<mxlibrary title="SYC Sailing Shapes" tags="sailing yacht racing course">${json.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</mxlibrary>\n`)
console.log(`Wrote ${entries.length} shapes to ${output}`)
