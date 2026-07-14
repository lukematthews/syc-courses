import Foundation

final class RecentCoursesStore: ObservableObject {
    @Published private(set) var recentCourseIDs: [String] = []

    private let key = "recentCourseIDs"
    private let legacyKey = "recentCourseNumbers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentCourseIDs = defaults.stringArray(forKey: key) ?? migrateLegacyValues()
    }

    func record(_ course: Course) {
        recentCourseIDs.removeAll { $0 == course.id }
        recentCourseIDs.insert(course.id, at: 0)
        recentCourseIDs = Array(recentCourseIDs.prefix(6))
        defaults.set(recentCourseIDs, forKey: key)
    }

    func clear() {
        recentCourseIDs = []
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: legacyKey)
    }

    private func migrateLegacyValues() -> [String] {
        let allCourses = CourseDataLoader.fixedCourses() + CourseDataLoader.laidCourses()
        let legacyNumbers = defaults.array(forKey: legacyKey) as? [Int] ?? []
        let migrated = legacyNumbers.compactMap { number in
            allCourses.first { $0.courseNumber == number }?.id
        }
        if !migrated.isEmpty {
            defaults.set(migrated, forKey: key)
            defaults.removeObject(forKey: legacyKey)
        }
        return migrated
    }
}
