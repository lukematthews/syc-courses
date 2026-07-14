#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ios_resources="$repo_root/ios/SYCCourses/Sources/SYCCourses/Resources"
android_main="$repo_root/android/app/src/main"

pack_namespace="$(node -e "const p=require('$ios_resources/course-pack.json'); process.stdout.write(p.assetNamespace)")"

rm -rf "$android_main/assets/course-charts"
mkdir -p "$android_main/assets/course-charts/$pack_namespace" "$android_main/assets/pennants" "$android_main/res/drawable"
cp "$ios_resources/course-pack.json" "$android_main/assets/course-pack.json"
cp "$ios_resources/fixed-courses.json" "$android_main/assets/fixed-courses.json"
cp "$ios_resources/laid-courses.json" "$android_main/assets/laid-courses.json"
cp "$ios_resources/marks.json" "$android_main/assets/marks.json"
cp "$ios_resources/mark-locations.png" "$android_main/assets/mark-locations.png"
cp "$ios_resources"/course-charts/"$pack_namespace"/*.png "$android_main/assets/course-charts/$pack_namespace/"
cp "$ios_resources/app-icon.png" "$android_main/res/drawable/app_icon.png"

if command -v rsvg-convert >/dev/null 2>&1; then
    for digit in {0..9}; do
        rsvg-convert -w 480 -h 180 \
            "$repo_root/src/assets/pennants/numeral-$digit.svg" \
            -o "$android_main/assets/pennants/numeral-$digit.png"
    done
elif [[ ! -f "$android_main/assets/pennants/numeral-0.png" ]]; then
    echo "rsvg-convert is required to create Android numeral pennant images." >&2
    exit 1
fi

echo "Android course pack data, charts, and app icon are in sync."
