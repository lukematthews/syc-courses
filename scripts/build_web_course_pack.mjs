import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { jsonFile, loadBundledCoursePack } from './course_pack.mjs'
import { generateMissingCourseCharts } from './generate_missing_course_charts.mjs'

const root = new URL('..', import.meta.url).pathname
const output = join(root, 'src/generated/course-pack')
const pack = loadBundledCoursePack(root)
generateMissingCourseCharts(pack, root)

mkdirSync(output, { recursive: true })
writeFileSync(join(output, 'manifest.json'), jsonFile(pack.manifest))
writeFileSync(join(output, 'fixed-courses.json'), jsonFile(pack.fixedCourses))
writeFileSync(join(output, 'laid-courses.json'), jsonFile(pack.laidCourses))
writeFileSync(join(output, 'marks.json'), jsonFile(pack.marks))

console.log(`Built ${pack.manifest.name} (${pack.manifest.packId}) web resources`)
