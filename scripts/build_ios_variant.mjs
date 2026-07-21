import { spawnSync } from 'node:child_process'
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const args = process.argv.slice(2)

function argument(name) {
  const index = args.indexOf(name)
  if (index === -1 || !args[index + 1]) throw new Error(`Missing ${name}`)
  return args[index + 1]
}

const variantId = argument('--variant')
const output = resolve(argument('--output'))
const registry = JSON.parse(readFileSync(join(root, 'course-apps.json'), 'utf8'))
const variant = registry.variants[variantId]
if (!variant) {
  console.error(`Unknown course app variant: ${variantId}`)
  process.exit(1)
}

const packDefinition = join(root, 'course-packs', variant.packDirectory, 'pack.json')
if (!existsSync(packDefinition)) {
  console.error(`${variant.displayName} is configured, but course-packs/${variant.packDirectory}/pack.json does not exist yet.`)
  process.exit(1)
}

if (process.env.PRODUCT_BUNDLE_IDENTIFIER && process.env.PRODUCT_BUNDLE_IDENTIFIER !== variant.bundleIdentifier) {
  console.error(`Xcode bundle identifier does not match course-apps.json for ${variantId}.`)
  process.exit(1)
}
if (process.env.COURSE_APP_DISPLAY_NAME && process.env.COURSE_APP_DISPLAY_NAME !== variant.displayName) {
  console.error(`Xcode display name does not match course-apps.json for ${variantId}.`)
  process.exit(1)
}

rmSync(output, { recursive: true, force: true })
mkdirSync(output, { recursive: true })

const environment = {
  ...process.env,
  COURSE_PACK_DIRECTORY: variant.packDirectory,
  IOS_RESOURCE_DIR: output,
}

for (const script of ['build_ios_resources.mjs', 'build_android_mark_locations.mjs']) {
  const result = spawnSync(process.execPath, [join(root, 'scripts', script)], {
    cwd: root,
    env: environment,
    stdio: 'inherit',
  })
  if (result.status !== 0) process.exit(result.status ?? 1)
}

const appIcon = join(
  root,
  'ios/SYCCoursesApp/SYCCoursesApp/Assets.xcassets',
  `${variant.appIcon}.appiconset`,
  'AppIcon-1024.png',
)
if (!existsSync(appIcon)) {
  console.error(`${variant.displayName} app icon does not exist at ${appIcon}.`)
  process.exit(1)
}
copyFileSync(appIcon, join(output, 'app-icon.png'))

console.log(`Built iOS variant ${variantId} (${variant.displayName}) in ${output}`)
