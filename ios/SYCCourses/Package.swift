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
            exclude: ["Info.plist"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SYCCoursesTests",
            dependencies: ["SYCCourses"]
        )
    ]
)
