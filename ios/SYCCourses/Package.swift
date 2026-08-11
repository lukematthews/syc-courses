// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SYCCourses",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SYCCourses", targets: ["SYCCourses"])
    ],
    targets: [
        .target(
            name: "SYCCourses",
            exclude: [
                "Info.plist",
                "Resources/app-icon.png",
                "Resources/course-charts",
                "Resources/mark-location-hotspots.json",
                "Resources/mark-location-syc-hotspots.json",
                "Resources/mark-locations.png",
                "Resources/mark-locations-syc.png",
                "Resources/pennants",
            ],
            resources: [
                .copy("Resources/course-pack.json"),
                .copy("Resources/fixed-courses.json"),
                .copy("Resources/laid-courses.json"),
                .copy("Resources/marks.json"),
                .copy("Resources/notices-to-competitors.json"),
                .copy("Resources/NTC_2026_Sat_Winter_1_Alan_Shiels_Race_2_Rev_0.pdf"),
            ]
        ),
        .testTarget(
            name: "SYCCoursesTests",
            dependencies: ["SYCCourses"]
        )
    ]
)
