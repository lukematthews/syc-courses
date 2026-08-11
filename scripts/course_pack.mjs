import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

export function loadBundledCoursePack(root, requestedPackDirectory = process.env.COURSE_PACK_DIRECTORY) {
  const selection = requestedPackDirectory
    ? { packDirectory: requestedPackDirectory }
    : readJson(join(root, 'course-packs/bundled-pack.json'))
  const packPath = join(root, 'course-packs', selection.packDirectory, 'pack.json')
  const definition = readJson(packPath)
  validateDefinition(definition, root)

  const fixedCourses = prepareCourses(
    readJson(join(root, definition.buildSources.fixedCourses)),
    definition,
    'fixed',
  )
  const laidCourses = prepareCourses(
    readJson(join(root, definition.buildSources.laidCourses)),
    definition,
    'laid',
  )
  const marks = readMarks(join(root, definition.buildSources.marks))
  validateData(definition, fixedCourses, laidCourses, marks)

  return {
    packDirectory: selection.packDirectory,
    definition,
    manifest: runtimeManifest(definition),
    fixedCourses,
    laidCourses,
    marks,
    chartDirectory: join(root, definition.buildSources.courseCharts),
  }
}

export function jsonFile(value) {
  return `${JSON.stringify(value, null, 2)}\n`
}

function prepareCourses(courses, definition, kind) {
  return courses.map((course) => {
    const { identitySuffix, ...runtimeCourse } = course
    const suffix = identitySuffix ? `-${identitySuffix}` : ''
    const generatedChartName = `generated-course-${course.courseNumber}${suffix}.png`
    const hasChartableRoute = course.rows.some(({ mark }) =>
      !/^(start|finish|course published|special course)/i.test(mark),
    )
    const chartName = course.chartImage
      ? course.chartImage.split('/').at(-1)
      : hasChartableRoute ? generatedChartName : ''
    return {
      ...runtimeCourse,
      id: `${definition.packId}/${kind}/course-${course.courseNumber}${suffix}`,
      packId: definition.packId,
      kind,
      groupId: course.groupId ?? kind,
      chartImage: chartName ? `/course-charts/${definition.assetNamespace}/${chartName}` : '',
      chartAlt: course.chartAlt || (chartName
        ? `Generated course chart for ${definition.shortName} Course ${course.courseNumber}. Not for navigation.`
        : ''),
    }
  })
}

function runtimeManifest(definition) {
  const { buildSources: _buildSources, ...manifest } = definition
  return {
    ...manifest,
    courseGroups: courseGroups(definition),
    resources: {
      fixedCourses: 'fixed-courses.json',
      laidCourses: 'laid-courses.json',
      marks: 'marks.json',
      courseCharts: `/course-charts/${definition.assetNamespace}`,
      quickBearingMaps: definition.navigation.quickBearingMapViews.map((view, index) => ({
        id: view.id,
        name: view.name,
        image: index === 0 ? 'mark-locations.png' : `mark-locations-${view.id}.png`,
        hotspots: index === 0 ? 'mark-location-hotspots.json' : `mark-location-${view.id}-hotspots.json`,
      })),
    },
  }
}

function readMarks(file) {
  if (file.endsWith('.json')) return readJson(file)

  const source = readFileSync(file, 'utf8')
  const arraySource = source.match(/export const marks: Mark\[] = (\[[\s\S]*?\n\])/)
  if (!arraySource) throw new Error(`Could not find marks array in ${file}`)

  const jsonLike = arraySource[1]
    .replace(/(\s*)([A-Za-z_][A-Za-z0-9_]*):/g, '$1"$2":')
    .replace(/'/g, '"')
    .replace(/,\s*([}\]])/g, '$1')
  return JSON.parse(jsonLike)
}

function validateDefinition(pack, root) {
  for (const field of ['schemaVersion', 'packId', 'assetNamespace', 'name', 'organiser', 'version']) {
    if (pack[field] === undefined || pack[field] === '') throw new Error(`Course pack is missing ${field}`)
  }
  if (pack.schemaVersion !== 1) throw new Error(`Unsupported course pack schema ${pack.schemaVersion}`)
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(pack.packId)) throw new Error(`Invalid packId: ${pack.packId}`)
  for (const path of Object.values(pack.buildSources ?? {})) {
    if (!existsSync(join(root, path))) throw new Error(`Missing course pack source: ${path}`)
  }
}

function validateData(pack, fixedCourses, laidCourses, marks) {
  const courseIds = [...fixedCourses, ...laidCourses].map((course) => course.id)
  if (new Set(courseIds).size !== courseIds.length) throw new Error('Course IDs must be unique')
  const groupIds = new Set(courseGroups(pack).map((group) => group.id))
  for (const course of [...fixedCourses, ...laidCourses]) {
    if (!groupIds.has(course.groupId)) throw new Error(`Course references missing group: ${course.groupId}`)
  }
  const markIds = new Set(marks.map((mark) => mark.id))
  if (markIds.size !== marks.length) throw new Error('Mark IDs must be unique')
  const mapViews = pack.navigation.quickBearingMapViews
  if (!Array.isArray(mapViews) || mapViews.length === 0) {
    throw new Error('Course pack requires at least one Quick Bearing map view')
  }
  const viewIds = new Set()
  for (const view of mapViews) {
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(view.id) || !view.name) {
      throw new Error(`Invalid Quick Bearing map view: ${JSON.stringify(view)}`)
    }
    if (viewIds.has(view.id)) throw new Error(`Duplicate Quick Bearing map view: ${view.id}`)
    viewIds.add(view.id)
  }
  for (const markId of [
    ...pack.navigation.startLineMarkIds,
    ...pack.navigation.finishLineMarkIds,
    pack.navigation.startFinishMarkId,
    ...mapViews.flatMap((view) => view.fitMarkIds ?? []),
  ]) {
    if (!markIds.has(markId)) throw new Error(`Navigation default references missing mark: ${markId}`)
  }
}

function courseGroups(pack) {
  return pack.courseGroups ?? pack.courseKinds.map((kind) => ({
    id: kind,
    name: kind === 'fixed' ? 'Fixed Mark Courses' : 'Laid Courses',
    kind,
  }))
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'))
}
