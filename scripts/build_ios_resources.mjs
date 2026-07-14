import { mkdirSync, copyFileSync, readdirSync, writeFileSync, rmSync } from 'node:fs'
import { basename, join } from 'node:path'
import { jsonFile, loadBundledCoursePack } from './course_pack.mjs'

const root = new URL('..', import.meta.url).pathname
const resourceDir = join(root, 'ios/SYCCourses/Sources/SYCCourses/Resources')
const pack = loadBundledCoursePack(root)
const chartOutput = join(resourceDir, 'course-charts', pack.definition.assetNamespace)

rmSync(join(resourceDir, 'course-charts'), { recursive: true, force: true })
rmSync(join(resourceDir, 'pennants'), { recursive: true, force: true })
mkdirSync(join(resourceDir, 'course-charts'), { recursive: true })
mkdirSync(chartOutput, { recursive: true })
mkdirSync(join(resourceDir, 'pennants'), { recursive: true })

writeFileSync(join(resourceDir, 'course-pack.json'), jsonFile(pack.manifest))
writeFileSync(join(resourceDir, 'fixed-courses.json'), jsonFile(pack.fixedCourses))
writeFileSync(join(resourceDir, 'laid-courses.json'), jsonFile(pack.laidCourses))
writeFileSync(join(resourceDir, 'marks.json'), jsonFile(pack.marks))

for (const file of readdirSync(pack.chartDirectory)) {
  if (file.endsWith('.png')) {
    copyFileSync(join(pack.chartDirectory, file), join(chartOutput, file))
  }
}

for (const file of readdirSync(join(root, 'src/assets/pennants'))) {
  if (file.endsWith('.svg')) {
    copyFileSync(join(root, 'src/assets/pennants', file), join(resourceDir, 'pennants', file))
  }
}

console.log(`Built ${pack.manifest.name} (${pack.manifest.packId}) iOS resources in ${basename(resourceDir)}`)
