import CoreLocation
import Foundation

final class ActiveRaceStore: ObservableObject {
    @Published private(set) var activeCourseID: String?
    @Published private(set) var activeMarkID: String?
    @Published private(set) var activeLegIndex: Int?

    private let courseIDKey = "activeRaceCourseID"
    private let legacyCourseNumberKey = "activeRaceCourseNumber"
    private let markIDKey = "activeRaceMarkID"
    private let legIndexKey = "activeRaceLegIndex"
    private let defaults: UserDefaults
    private let marks: [Mark]
    private let fixedCourses: [Course]

    init(defaults: UserDefaults = .standard, marks: [Mark] = CourseDataLoader.marks(), fixedCourses: [Course] = CourseDataLoader.fixedCourses()) {
        self.defaults = defaults
        self.marks = marks
        self.fixedCourses = fixedCourses
        activeCourseID = defaults.string(forKey: courseIDKey)
        if activeCourseID == nil,
           let legacyNumber = defaults.object(forKey: legacyCourseNumberKey) as? Int,
           let migratedCourse = fixedCourses.first(where: { $0.courseNumber == legacyNumber }) {
            activeCourseID = migratedCourse.id
            defaults.set(migratedCourse.id, forKey: courseIDKey)
            defaults.removeObject(forKey: legacyCourseNumberKey)
        }
        activeMarkID = defaults.string(forKey: markIDKey)
        activeLegIndex = defaults.object(forKey: legIndexKey) as? Int

        if activeCourse == nil {
            activeCourseID = nil
            activeMarkID = nil
            activeLegIndex = nil
        } else {
            let restoredIndex = activeLegIndex
                ?? courseMarks.firstIndex { $0.id == activeMarkID }
                ?? 0
            setActiveLegIndex(restoredIndex)
        }
    }

    var activeCourse: Course? {
        guard let activeCourseID else { return nil }
        return fixedCourses.first { $0.id == activeCourseID }
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
        guard let activeLegIndex, courseMarks.indices.contains(activeLegIndex) else { return nil }
        return courseMarks[activeLegIndex]
    }

    var activeMarkIndex: Int? {
        activeLegIndex
    }

    var activeRoundingSide: String? {
        guard let activeLegIndex,
              navigationLegs.indices.contains(activeLegIndex)
        else { return nil }
        return navigationLegs[activeLegIndex].side
    }

    var navigationLegs: [ActiveRaceNavigationLeg] {
        guard let activeCourse else { return [] }
        return ActiveRaceCourseBuilder.navigationLegs(for: activeCourse, marks: marks)
    }

    var isCourseActive: Bool {
        activeCourse != nil
    }

    func setActiveCourse(_ course: Course) {
        guard !course.isLaidMarkCourse else { return }
        activeCourseID = course.id
        setActiveLegIndex(0)
        persist()
    }

    func setActiveMark(_ mark: Mark) {
        let matchingIndices = courseMarks.indices.filter { courseMarks[$0].id == mark.id }
        guard let index = matchingIndices.first(where: { $0 >= (activeLegIndex ?? 0) })
            ?? matchingIndices.first
        else { return }
        setActiveLegIndex(index)
        persist()
    }

    func advanceMark() {
        guard !courseMarks.isEmpty else { return }
        let nextIndex = min((activeMarkIndex ?? -1) + 1, courseMarks.count - 1)
        setActiveLegIndex(nextIndex)
        persist()
    }

    func retreatMark() {
        guard !courseMarks.isEmpty else { return }
        let nextIndex = max((activeMarkIndex ?? 0) - 1, 0)
        setActiveLegIndex(nextIndex)
        persist()
    }

    func clearActiveCourse() {
        activeCourseID = nil
        activeMarkID = nil
        activeLegIndex = nil
        defaults.removeObject(forKey: courseIDKey)
        defaults.removeObject(forKey: legacyCourseNumberKey)
        defaults.removeObject(forKey: markIDKey)
        defaults.removeObject(forKey: legIndexKey)
    }

    private func persist() {
        if let activeCourseID {
            defaults.set(activeCourseID, forKey: courseIDKey)
        } else {
            defaults.removeObject(forKey: courseIDKey)
        }

        if let activeMarkID {
            defaults.set(activeMarkID, forKey: markIDKey)
        } else {
            defaults.removeObject(forKey: markIDKey)
        }

        if let activeLegIndex {
            defaults.set(activeLegIndex, forKey: legIndexKey)
        } else {
            defaults.removeObject(forKey: legIndexKey)
        }
    }

    private func setActiveLegIndex(_ index: Int) {
        guard !courseMarks.isEmpty else {
            activeLegIndex = nil
            activeMarkID = nil
            return
        }
        let clampedIndex = min(max(index, 0), courseMarks.count - 1)
        activeLegIndex = clampedIndex
        activeMarkID = courseMarks[clampedIndex].id
    }
}

struct ActiveRaceNavigationLeg: Hashable {
    let mark: Mark
    let side: String
}

enum ActiveRaceCourseBuilder {
    static func navigationLegs(for course: Course, marks: [Mark] = CourseDataLoader.marks()) -> [ActiveRaceNavigationLeg] {
        course.rows.compactMap { row in
            guard !row.isCourseTotalRow, !row.isPassThroughRow, !row.isStartRow,
                  let mark = resolvedMark(for: row.mark, marks: marks)
            else { return nil }
            return ActiveRaceNavigationLeg(mark: mark, side: row.side)
        }
    }

    static func navigationMarks(for course: Course, marks: [Mark] = CourseDataLoader.marks()) -> [Mark] {
        navigationLegs(for: course, marks: marks).map(\.mark)
    }

    static func courseLineMarks(for course: Course, marks: [Mark] = CourseDataLoader.marks()) -> [Mark] {
        var lineMarks: [Mark] = []
        if let start = CourseDataLoader.startFinishMark(in: marks) {
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
            return CourseDataLoader.startFinishMark(in: marks)
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
        kind == .laid
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
