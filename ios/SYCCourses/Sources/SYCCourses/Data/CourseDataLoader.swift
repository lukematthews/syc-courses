import Foundation

enum CourseDataLoader {
    static func fixedCourses() -> [Course] {
        load("fixed-courses")
    }

    static func laidCourses() -> [Course] {
        load("laid-courses")
    }

    static func marks() -> [Mark] {
        load("marks")
    }

    static func findMark(named name: String, in marks: [Mark] = marks()) -> Mark? {
        let normalized = normalizeMarkName(name)
        return marks.first { mark in
            ([mark.name] + mark.aliases).contains { normalizeMarkName($0) == normalized }
        }
    }

    private static func load<T: Decodable>(_ resource: String) -> T {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else {
            fatalError("Missing bundled resource: \(resource).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Could not decode \(resource).json: \(error)")
        }
    }

    private static func normalizeMarkName(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
