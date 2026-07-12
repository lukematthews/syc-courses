#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ios_resources="$repo_root/ios/SYCCourses/Sources/SYCCourses/Resources"
android_main="$repo_root/android/app/src/main"

mkdir -p "$android_main/assets/course-charts" "$android_main/res/drawable"
cp "$ios_resources/fixed-courses.json" "$android_main/assets/fixed-courses.json"
cp "$ios_resources/laid-courses.json" "$android_main/assets/laid-courses.json"
cp "$ios_resources/marks.json" "$android_main/assets/marks.json"
cp "$ios_resources"/course-charts/*.png "$android_main/assets/course-charts/"
cp "$ios_resources/app-icon.png" "$android_main/res/drawable/app_icon.png"

echo "Android course data, charts, and app icon are in sync."
