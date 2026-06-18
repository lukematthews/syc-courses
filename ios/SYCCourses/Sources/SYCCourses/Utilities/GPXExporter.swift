import Foundation

enum GPXExportError: LocalizedError, Equatable {
    case noRoutePoints
    case missingMark(String)
    case missingCoordinates(String)
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .noRoutePoints:
            "Could not export route. This course does not contain route marks."
        case let .missingMark(mark):
            "Could not export route. \(mark) is not available."
        case .missingCoordinates:
            "Could not export route. One or more marks are missing coordinates."
        case .fileWriteFailed:
            "Could not export route. The GPX file could not be created."
        }
    }
}

enum GPXExporter {
    static func xml(for course: Course, marks: [Mark]) throws -> String {
        let routePoints = try routePoints(for: course, marks: marks)
        guard !routePoints.isEmpty else {
            throw GPXExportError.noRoutePoints
        }

        var seenMarkIDs = Set<String>()
        let waypointEntries = routePoints.compactMap { routePoint -> String? in
            guard seenMarkIDs.insert(routePoint.mark.id).inserted else { return nil }
            return """
              <wpt lat="\(coordinate(routePoint.mark.latitude))" lon="\(coordinate(routePoint.mark.longitude))">
                <name>\(escape(routePoint.name))</name>
              </wpt>
            """
        }
        let routeEntries = routePoints.map { routePoint in
            """
                <rtept lat="\(coordinate(routePoint.mark.latitude))" lon="\(coordinate(routePoint.mark.longitude))">
                  <name>\(escape(routePoint.name))</name>
                </rtept>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="SYC Courses" xmlns="http://www.topografix.com/GPX/1/1">
        \(waypointEntries.joined(separator: "\n"))
          <rte>
            <name>\(escape("SYC Course \(course.courseNumber)"))</name>
        \(routeEntries.joined(separator: "\n"))
          </rte>
        </gpx>
        """
    }

    static func writeTemporaryFile(for course: Course, marks: [Mark]) throws -> URL {
        let xml = try xml(for: course, marks: marks)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SYC_Course_\(course.courseNumber)")
            .appendingPathExtension("gpx")

        do {
            try xml.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            throw GPXExportError.fileWriteFailed
        }
    }

    private static func routePoints(for course: Course, marks: [Mark]) throws -> [GPXRoutePoint] {
        try course.rows.compactMap { row in
            let name = normalized(row.mark)
            guard name != "total", name != "sub-total", name != "subtotal" else {
                return nil
            }

            let mark = try resolvedMark(named: row.mark, in: marks)
            guard isValidCoordinate(mark) else {
                throw GPXExportError.missingCoordinates(row.mark)
            }
            return GPXRoutePoint(name: row.mark, mark: mark)
        }
    }

    private static func resolvedMark(named name: String, in marks: [Mark]) throws -> Mark {
        let normalizedName = normalized(name)
        let lookupName = normalizedName == "start" || normalizedName == "finish" ? "SYC 4" : name
        guard let mark = CourseDataLoader.findMark(named: lookupName, in: marks) else {
            throw GPXExportError.missingMark(name)
        }
        return mark
    }

    private static func isValidCoordinate(_ mark: Mark) -> Bool {
        mark.latitude.isFinite
            && mark.longitude.isFinite
            && abs(mark.latitude) <= 90
            && abs(mark.longitude) <= 180
    }

    private static func normalized(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func coordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private struct GPXRoutePoint {
    let name: String
    let mark: Mark
}
