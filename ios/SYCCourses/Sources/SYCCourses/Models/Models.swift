import Foundation

struct Course: Codable, Identifiable, Hashable {
    var id: Int { courseNumber }
    let courseNumber: Int
    let route: String?
    let passInstruction: String
    let rows: [CourseLeg]
    let totalDistance: String
    let chartImage: String
    let chartAlt: String
    let dataStatus: String
    let sourcePage: Int
    let comparableCourseNote: String?
}

struct CourseLeg: Codable, Identifiable, Hashable {
    var id = UUID()
    let mark: String
    let side: String
    let bearing: String
    let distance: String

    enum CodingKeys: String, CodingKey {
        case mark, side, bearing, distance
    }
}

struct Mark: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]
    let latitude: Double
    let longitude: Double
    let description: String?
    let coordinatesStatus: String
}

enum CourseKind: String, CaseIterable, Identifiable {
    case fixed
    case laid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixed: "Fixed Mark Courses"
        case .laid: "Laid Courses"
        }
    }
}

struct BearingSnapshot: Equatable {
    let currentLatitude: Double
    let currentLongitude: Double
    let bearingTrue: Double
    let distanceNm: Double
    let speedOverGroundKnots: Double?
    let horizontalAccuracyMeters: Double
    let timestamp: Date

    var timeToMark: TimeInterval? {
        guard let speedOverGroundKnots, speedOverGroundKnots > 0.2 else { return nil }
        return (distanceNm / speedOverGroundKnots) * 3600
    }
}

struct StartAssistSnapshot: Equatable {
    let startTime: Date
    let timeToStart: TimeInterval
    let timeToMark: TimeInterval?
    let timeToBurn: TimeInterval?
}

enum LineCrossingStatus: Equatable {
    case approachingLine
    case crossingAhead
    case crossingOutsideSegment
    case parallel
    case movingAway
    case insufficientData(LineCrossingUnavailableReason)
}

enum LineCrossingUnavailableReason: Equatable {
    case noGPS
    case noCOG
    case noSOG
}

struct LineCrossingResult: Equatable {
    let status: LineCrossingStatus
    let distanceMeters: Double?
    let timeToLine: TimeInterval?
}
