import Foundation

enum CourseResourceLocator {
    static func url(
        forResource name: String,
        withExtension fileExtension: String,
        subdirectory: String? = nil
    ) -> URL? {
        let appSubdirectory = ["CoursePackResources", subdirectory]
            .compactMap { $0 }
            .joined(separator: "/")
        return Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: appSubdirectory
        ) ?? Bundle.module.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
    }
}
