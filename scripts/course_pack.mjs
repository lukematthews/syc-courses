import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

export function loadBundledCoursePack(root) {
  const selection = readJson(join(root, 'course-packs/bundled-pack.json'))
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
  return courses.map((course) => ({
    ...course,
    id: `${definition.packId}/${kind}/course-${course.courseNumber}`,
    packId: definition.packId,
    kind,
    chartImage: course.chartImage
      ? `/course-charts/${definition.assetNamespace}/${course.chartImage.split('/').at(-1)}`
      : '',
  }))
}

function runtimeManifest(definition) {
  const { buildSources: _buildSources, ...manifest } = definition
  return {
    ...manifest,
    resources: {
      fixedCourses: 'fixed-courses.json',
      laidCourses: 'laid-courses.json',
      marks: 'marks.json',
      courseCharts: `/course-charts/${definition.assetNamespace}`,
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
  const markIds = new Set(marks.map((mark) => mark.id))
  if (markIds.size !== marks.length) throw new Error('Mark IDs must be unique')
  for (const markId of [
    ...pack.navigation.startLineMarkIds,
    ...pack.navigation.finishLineMarkIds,
    pack.navigation.startFinishMarkId,
  ]) {
    if (!markIds.has(markId)) throw new Error(`Navigation default references missing mark: ${markId}`)
  }
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'))
}
