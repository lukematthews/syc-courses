import Foundation

final class RecentCoursesStore: ObservableObject {
    @Published private(set) var recentCourseNumbers: [Int] = []

    private let key = "recentCourseNumbers"
    private let defaults = UserDefaults.standard

    init() {
        recentCourseNumbers = defaults.array(forKey: key) as? [Int] ?? []
    }

    func record(_ course: Course) {
        recentCourseNumbers.removeAll { $0 == course.courseNumber }
        recentCourseNumbers.insert(course.courseNumber, at: 0)
        recentCourseNumbers = Array(recentCourseNumbers.prefix(6))
        defaults.set(recentCourseNumbers, forKey: key)
    }

    func clear() {
        recentCourseNumbers = []
        defaults.removeObject(forKey: key)
    }
}
