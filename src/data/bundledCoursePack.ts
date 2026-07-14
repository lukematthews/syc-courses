import manifestJson from '../generated/course-pack/manifest.json'
import fixedCoursesJson from '../generated/course-pack/fixed-courses.json'
import laidCoursesJson from '../generated/course-pack/laid-courses.json'
import marksJson from '../generated/course-pack/marks.json'

export type CourseKind = 'fixed' | 'laid'

export type CourseRow = {
  mark: string
  side: string
  bearing: string
  distance: string
}

export type Course = {
  id: string
  packId: string
  kind: CourseKind
  courseNumber: number
  route?: string
  passInstruction: string
  rows: CourseRow[]
  totalDistance: string
  chartImage: string
  chartAlt: string
  dataStatus: string
  sourcePage: number
  comparableCourseNote?: string
}

export type Mark = {
  id: string
  name: string
  aliases: string[]
  latitude: number
  longitude: number
  description?: string
  coordinatesStatus: string
}

export type CoursePackManifest = {
  schemaVersion: number
  packId: string
  assetNamespace: string
  name: string
  shortName: string
  organiser: string
  version: string
  source: {
    type: string
    title: string
    url?: string
  }
  courseKinds: CourseKind[]
  navigation: {
    startLineMarkIds: string[]
    finishLineMarkIds: string[]
    startFinishMarkId: string
  }
  resources: {
    fixedCourses: string
    laidCourses: string
    marks: string
    courseCharts: string
  }
}

export const coursePack = manifestJson as CoursePackManifest
export const courses = fixedCoursesJson as Course[]
export const laidCourses = laidCoursesJson as Course[]
export const marks = marksJson as Mark[]

function normalizeMarkName(value: string) {
  return value.replace(/\s*\([^)]*\)/g, '').replace(/\s+/g, ' ').trim().toLowerCase()
}

export function findMarkByName(name: string) {
  const normalizedName = normalizeMarkName(name)
  return marks.find((mark) =>
    [mark.name, ...mark.aliases].some((candidate) => normalizeMarkName(candidate) === normalizedName),
  )
}
