import { resolve } from 'node:path'
import { generateMissingCourseCharts } from './generate_missing_course_charts.mjs'
import { loadBundledCoursePack } from './course_pack.mjs'

const root = resolve(new URL('..', import.meta.url).pathname)
const packDirectory = process.argv[2] ?? process.env.COURSE_PACK_DIRECTORY
if (!packDirectory) {
  console.error('Usage: node scripts/build_course_charts.mjs <course-pack-directory>')
  process.exit(1)
}

const pack = loadBundledCoursePack(root, packDirectory)
generateMissingCourseCharts(pack, root)
