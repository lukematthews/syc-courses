#if canImport(XCTest)
@testable import SYCCourses
import XCTest

final class GPXExporterTests: XCTestCase {
    func testGPXIncludesVersionCreatorAndRouteName() throws {
        let xml = try GPXExporter.xml(for: course(number: 4, marks: ["SYC 3"]), marks: testMarks)

        XCTAssertTrue(xml.contains(#"<gpx version="1.1" creator="SYC Courses""#))
        XCTAssertTrue(xml.contains("<name>SYC Course 4</name>"))
    }

    func testRoutePointsFollowCourseTableOrder() throws {
        let xml = try GPXExporter.xml(
            for: course(number: 4, marks: ["SYC 3", "SYC 2", "SYC 5", "FINISH"]),
            marks: testMarks
        )

        XCTAssertLessThan(xml.range(of: "<name>SYC 3</name>")!.lowerBound, xml.range(of: "<name>SYC 2</name>")!.lowerBound)
        XCTAssertLessThan(xml.range(of: "<name>SYC 2</name>")!.lowerBound, xml.range(of: "<name>SYC 5</name>")!.lowerBound)
        XCTAssertLessThan(xml.range(of: "<name>SYC 5</name>")!.lowerBound, xml.range(of: "<name>FINISH</name>")!.lowerBound)
        XCTAssertTrue(xml.contains(#"<rtept lat="-37.946833" lon="144.990000">"#))
    }

    func testWaypointEntriesAreDeduplicated() throws {
        let xml = try GPXExporter.xml(for: course(number: 9, marks: ["SYC 3", "SYC 3", "SYC 2"]), marks: testMarks)

        XCTAssertEqual(xml.components(separatedBy: "<wpt ").count - 1, 2)
        XCTAssertEqual(xml.components(separatedBy: "<rtept ").count - 1, 3)
    }

    func testMarkNamesAreEscaped() throws {
        let mark = Mark(
            id: "special",
            name: "A&B <C>",
            aliases: [],
            latitude: -37,
            longitude: 144,
            description: nil,
            coordinatesStatus: "verified"
        )
        let xml = try GPXExporter.xml(for: course(number: 10, marks: ["A&B <C>"]), marks: [mark])

        XCTAssertTrue(xml.contains("A&amp;B &lt;C&gt;"))
    }

    func testMissingCoordinatesThrowsClearError() {
        let mark = Mark(
            id: "bad",
            name: "Bad Mark",
            aliases: [],
            latitude: .nan,
            longitude: 144,
            description: nil,
            coordinatesStatus: "missing"
        )

        XCTAssertThrowsError(try GPXExporter.xml(for: course(number: 11, marks: ["Bad Mark"]), marks: [mark])) { error in
            XCTAssertEqual(error as? GPXExportError, .missingCoordinates("Bad Mark"))
            XCTAssertEqual(error.localizedDescription, "Could not export route. One or more marks are missing coordinates.")
        }
    }

    private var testMarks: [Mark] {
        [
            mark(id: "syc-2", name: "SYC 2", latitude: -37.943333, longitude: 144.966167),
            mark(id: "syc-3", name: "SYC 3", latitude: -37.937333, longitude: 144.9875),
            mark(id: "syc-4", name: "SYC 4", latitude: -37.946833, longitude: 144.99),
            mark(id: "syc-5", name: "SYC 5", latitude: -37.980167, longitude: 144.973),
        ]
    }

    private func course(number: Int, marks: [String]) -> Course {
        Course(
            courseNumber: number,
            route: nil,
            passInstruction: "All marks to Port",
            rows: marks.map { CourseLeg(mark: $0, side: "Port", bearing: "", distance: "") }
                + [CourseLeg(mark: "TOTAL", side: "", bearing: "", distance: "")],
            totalDistance: "6.05 nm",
            chartImage: "",
            chartAlt: "",
            dataStatus: "test",
            sourcePage: 0,
            comparableCourseNote: "Comparable Course: 2"
        )
    }

    private func mark(id: String, name: String, latitude: Double, longitude: Double) -> Mark {
        Mark(
            id: id,
            name: name,
            aliases: [],
            latitude: latitude,
            longitude: longitude,
            description: nil,
            coordinatesStatus: "verified"
        )
    }
}
#endif
