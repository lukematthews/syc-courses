import { mkdirSync, copyFileSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs'
import { basename, join } from 'node:path'

const root = new URL('..', import.meta.url).pathname
const resourceDir = join(root, 'ios/SYCCourses/Sources/SYCCourses/Resources')

rmSync(join(resourceDir, 'course-charts'), { recursive: true, force: true })
rmSync(join(resourceDir, 'pennants'), { recursive: true, force: true })
mkdirSync(join(resourceDir, 'course-charts'), { recursive: true })
mkdirSync(join(resourceDir, 'pennants'), { recursive: true })

copyFileSync(join(root, 'source/extracted-courses.json'), join(resourceDir, 'fixed-courses.json'))
copyFileSync(join(root, 'source/extracted-laid-courses.json'), join(resourceDir, 'laid-courses.json'))

for (const file of readdirSync(join(root, 'public/course-charts'))) {
  if (file.endsWith('.png')) {
    copyFileSync(join(root, 'public/course-charts', file), join(resourceDir, 'course-charts', file))
  }
}

for (const file of readdirSync(join(root, 'src/assets/pennants'))) {
  if (file.endsWith('.svg')) {
    copyFileSync(join(root, 'src/assets/pennants', file), join(resourceDir, 'pennants', file))
  }
}

const marksTs = readFileSync(join(root, 'src/data/marks.ts'), 'utf8')
const arraySource = marksTs.match(/export const marks: Mark\[] = (\[[\s\S]*?\n\])/)

if (!arraySource) {
  throw new Error('Could not find marks array in src/data/marks.ts')
}

const jsonLike = arraySource[1]
  .replace(/(\s*)([A-Za-z_][A-Za-z0-9_]*):/g, '$1"$2":')
  .replace(/'/g, '"')
  .replace(/,\s*([}\]])/g, '$1')

writeFileSync(join(resourceDir, 'marks.json'), `${JSON.stringify(JSON.parse(jsonLike), null, 2)}\n`)

console.log(`Built iOS resources in ${basename(resourceDir)}`)
