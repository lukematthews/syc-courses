import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const draft = JSON.parse(readFileSync(join(root, 'design/course-packs/festival-of-sails-2026.draft.json')))
const output = join(root, 'course-packs/festival-of-sails-2026')

const markBySlug = new Map(draft.marks.map((mark) => [mark.markId.split('/').at(-1), mark]))
const displayName = (slug) => markBySlug.get(slug)?.displayName ?? slug

function rowsFor(course) {
  return course.route.map(([mark, side, condition]) => ({
    mark: displayName(mark),
    side: [side, condition].filter(Boolean).join(' — '),
    bearing: '',
    distance: '',
  }))
}

function sourcePage(course) {
  return course.source.pdfPage ?? course.source.pdfPages?.[0] ?? 0
}

function signalText(signal) {
  return signal.value ?? signal.valuesTopToBottom?.join(' over ') ?? ''
}

function convertCourse(course, courseNumber) {
  return {
    courseNumber,
    route: course.displayName,
    passInstruction: course.unresolvedAmbiguities?.join(' ') ?? '',
    rows: rowsFor(course),
    totalDistance: course.distanceNmApprox ? `${course.distanceNmApprox} nm approx.` : '',
    chartImage: course.chartImage,
    chartAlt: course.chartAlt,
    dataStatus: 'official-2026-si-draft-requires-race-day-verification',
    sourcePage: sourcePage(course),
    comparableCourseNote: course.signal
      ? `Signal: ${signalText(course.signal)}. Dynamic marks and lines require race-day confirmation.`
      : 'Dynamic marks and lines require race-day confirmation.',
  }
}

const fixedCourses = [
  ...draft.fullyNavigableCourses.map((course) =>
    convertCourse(course, Number(course.displayName.match(/\d+$/)[0])),
  ),
  ...draft.passageCourses.map((course, index) => convertCourse(course, 20 + index)),
]
const laidCourses = draft.courseTemplates.map((course) =>
  convertCourse(course, Number(course.signal.value)),
)

// Course Pack v1 can navigate only coordinate-bearing points. Dynamic marks remain
// visible in course tables but are deliberately omitted from the navigation mark list.
const marks = draft.marks
  .filter((mark) => Number.isFinite(mark.position?.latitude) && Number.isFinite(mark.position?.longitude))
  .map((mark) => ({
    id: mark.markId.split('/').at(-1),
    name: mark.displayName,
    aliases: mark.aliases ?? [],
    latitude: mark.position.latitude,
    longitude: mark.position.longitude,
    description: [mark.position.coordinateText, mark.notes?.join(' ')].filter(Boolean).join(' — '),
    coordinatesStatus: mark.position.kind,
  }))

mkdirSync(output, { recursive: true })
writeFileSync(join(output, 'fixed-courses.json'), `${JSON.stringify(fixedCourses, null, 2)}\n`)
writeFileSync(join(output, 'laid-courses.json'), `${JSON.stringify(laidCourses, null, 2)}\n`)
writeFileSync(join(output, 'marks.json'), `${JSON.stringify(marks, null, 2)}\n`)

console.log(`Built Festival sources: ${fixedCourses.length} fixed, ${laidCourses.length} laid, ${marks.length} positioned marks`)
