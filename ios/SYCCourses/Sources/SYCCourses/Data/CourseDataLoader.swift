import Foundation

enum CourseDataLoader {
    static let bundledPack: CoursePack = load("course-pack")

    static func fixedCourses() -> [Course] {
        load(resourceName(bundledPack.resources.fixedCourses))
    }

    static func laidCourses() -> [Course] {
        load(resourceName(bundledPack.resources.laidCourses))
    }

    static func allCourses() -> [Course] {
        fixedCourses() + laidCourses()
    }

    static var courseGroups: [CourseGroup] {
        bundledPack.courseGroups ?? CourseKind.allCases.map {
            CourseGroup(id: $0.rawValue, name: $0.title, kind: $0)
        }
    }

    static func courses(groupId: String) -> [Course] {
        allCourses().filter { ($0.groupId ?? $0.kind.rawValue) == groupId }
    }

    static func marks() -> [Mark] {
        load(resourceName(bundledPack.resources.marks))
    }

    static func findMark(named name: String, in marks: [Mark] = marks()) -> Mark? {
        let normalized = normalizeMarkName(name)
        return marks.first { mark in
            ([mark.name] + mark.aliases).contains { normalizeMarkName($0) == normalized }
        }
    }

    static func mark(id: String, in marks: [Mark] = marks()) -> Mark? {
        marks.first { $0.id == id }
    }

    static func startLineMarks(in marks: [Mark] = marks()) -> [Mark] {
        bundledPack.navigation.startLineMarkIds.compactMap { mark(id: $0, in: marks) }
    }

    static func finishLineMarks(in marks: [Mark] = marks()) -> [Mark] {
        bundledPack.navigation.finishLineMarkIds.compactMap { mark(id: $0, in: marks) }
    }

    static func startFinishMark(in marks: [Mark] = marks()) -> Mark? {
        mark(id: bundledPack.navigation.startFinishMarkId, in: marks)
    }

    private static func load<T: Decodable>(_ resource: String) -> T {
        guard let url = CourseResourceLocator.url(forResource: resource, withExtension: "json") else {
            fatalError("Missing bundled resource: \(resource).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Could not decode \(resource).json: \(error)")
        }
    }

    private static func resourceName(_ value: String) -> String {
        URL(fileURLWithPath: value).deletingPathExtension().lastPathComponent
    }

    private static func normalizeMarkName(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
