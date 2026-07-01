import CoreLocation
import Foundation

final class ActiveRaceStore: ObservableObject {
    @Published private(set) var activeCourseNumber: Int?
    @Published private(set) var activeMarkID: String?

    private let courseNumberKey = "activeRaceCourseNumber"
    private let markIDKey = "activeRaceMarkID"
    private let defaults: UserDefaults
    private let marks: [Mark]
    private let fixedCourses: [Course]

    init(defaults: UserDefaults = .standard, marks: [Mark] = CourseDataLoader.marks(), fixedCourses: [Course] = CourseDataLoader.fixedCourses()) {
        self.defaults = defaults
        self.marks = marks
        self.fixedCourses = fixedCourses
        activeCourseNumber = defaults.object(forKey: courseNumberKey) as? Int
        activeMarkID = defaults.string(forKey: markIDKey)

        if activeCourse == nil {
            activeCourseNumber = nil
            activeMarkID = nil
        } else if activeMark == nil {
            activeMarkID = courseMarks.first?.id
        }
    }

    var activeCourse: Course? {
        guard let activeCourseNumber else { return nil }
        return fixedCourses.first { $0.courseNumber == activeCourseNumber }
    }

    var courseMarks: [Mark] {
        guard let activeCourse else { return [] }
        return ActiveRaceCourseBuilder.navigationMarks(for: activeCourse, marks: marks)
    }

    var courseCoordinates: [CLLocationCoordinate2D] {
        guard let activeCourse else { return [] }
        return ActiveRaceCourseBuilder.courseLineMarks(for: activeCourse, marks: marks).map(\.coordinate)
    }

    var courseLineMarkIDs: [String] {
        guard let activeCourse else { return [] }
        return ActiveRaceCourseBuilder.courseLineMarks(for: activeCourse, marks: marks).map(\.id)
    }

    var activeMark: Mark? {
        guard let activeMarkID else { return nil }
        return marks.first { $0.id == activeMarkID }
    }

    var activeMarkIndex: Int? {
        guard let activeMarkID else { return nil }
        return courseMarks.firstIndex { $0.id == activeMarkID }
    }

    var isCourseActive: Bool {
        activeCourse != nil
    }

    func setActiveCourse(_ course: Course) {
        guard !course.isLaidMarkCourse else { return }
        activeCourseNumber = course.courseNumber
        activeMarkID = ActiveRaceCourseBuilder.navigationMarks(for: course, marks: marks).first?.id
        persist()
    }

    func setActiveMark(_ mark: Mark) {
        activeMarkID = mark.id
        defaults.set(mark.id, forKey: markIDKey)
    }

    func advanceMark() {
        guard !courseMarks.isEmpty else { return }
        let nextIndex = min((activeMarkIndex ?? -1) + 1, courseMarks.count - 1)
        activeMarkID = courseMarks[nextIndex].id
        defaults.set(activeMarkID, forKey: markIDKey)
    }

    func retreatMark() {
        guard !courseMarks.isEmpty else { return }
        let nextIndex = max((activeMarkIndex ?? 0) - 1, 0)
        activeMarkID = courseMarks[nextIndex].id
        defaults.set(activeMarkID, forKey: markIDKey)
    }

    func clearActiveCourse() {
        activeCourseNumber = nil
        activeMarkID = nil
        defaults.removeObject(forKey: courseNumberKey)
        defaults.removeObject(forKey: markIDKey)
    }

    private func persist() {
        if let activeCourseNumber {
            defaults.set(activeCourseNumber, forKey: courseNumberKey)
        } else {
            defaults.removeObject(forKey: courseNumberKey)
        }

        if let activeMarkID {
            defaults.set(activeMarkID, forKey: markIDKey)
        } else {
            defaults.removeObject(forKey: markIDKey)
        }
    }
}

enum ActiveRaceCourseBuilder {
    static func navigationMarks(for course: Course, marks: [Mark] = CourseDataLoader.marks()) -> [Mark] {
        course.rows.compactMap { row in
            guard !row.isCourseTotalRow, !row.isPassThroughRow, !row.isStartRow else { return nil }
            return resolvedMark(for: row.mark, marks: marks)
        }
    }

    static func courseLineMarks(for course: Course, marks: [Mark] = CourseDataLoader.marks()) -> [Mark] {
        var lineMarks: [Mark] = []
        if let start = CourseDataLoader.findMark(named: "SYC 4", in: marks) {
            lineMarks.append(start)
        }

        for row in course.rows {
            guard !row.isCourseTotalRow, !row.isPassThroughRow else { continue }
            guard let mark = resolvedMark(for: row.mark, marks: marks) else { continue }
            if lineMarks.last?.id != mark.id {
                lineMarks.append(mark)
            }
        }

        return lineMarks
    }

    private static func resolvedMark(for name: String, marks: [Mark]) -> Mark? {
        if name.normalizedCourseMarkName == "start" || name.normalizedCourseMarkName == "finish" {
            return CourseDataLoader.findMark(named: "SYC 4", in: marks)
        }
        return CourseDataLoader.findMark(named: name, in: marks)
    }
}

extension Mark {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Course {
    var isLaidMarkCourse: Bool {
        courseNumber >= 80
    }
}

extension CourseLeg {
    var isCourseTotalRow: Bool {
        let name = mark.normalizedCourseMarkName
        return name == "total" || name == "sub-total" || name == "subtotal"
    }

    var isStartRow: Bool {
        mark.normalizedCourseMarkName == "start"
    }

    var isStartOrFinishRow: Bool {
        let name = mark.normalizedCourseMarkName
        return name == "start" || name == "finish"
    }

    var isPassThroughRow: Bool {
        side.normalizedCourseMarkName == "pass"
            || bearing.normalizedCourseMarkName == "na"
            || distance.normalizedCourseMarkName == "na"
    }
}

extension String {
    var normalizedCourseMarkName: String {
        replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
