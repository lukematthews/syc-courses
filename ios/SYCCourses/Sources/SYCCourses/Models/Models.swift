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

enum BoatReferencePoint: String, Equatable {
    case gps
    case bow
}

enum LineCrossingDegradedReason: Equatable {
    case missingHeading
    case missingGeometry
    case disabled
}

enum BoatReferenceBearingSource: String, Codable, CaseIterable, Identifiable, Equatable {
    case cog
    case heading

    var id: String { rawValue }
}

struct BoatGeometrySettings: Codable, Equatable {
    var bowOffsetMeters: Double = 9.4
    var gpsOffsetStarboardMeters: Double = 0
    var useBowOffsetForLineAssist: Bool = true
    var referenceBearingSource: BoatReferenceBearingSource = .cog
}

struct LatLon: Equatable {
    let latitude: Double
    let longitude: Double
}

struct BoatReferencePointResult: Equatable {
    let position: LatLon
    let referencePoint: BoatReferencePoint
    let isBowOffsetApplied: Bool
    let isDegraded: Bool
    let degradedReason: LineCrossingDegradedReason?
}

struct LineCrossingResult: Equatable {
    let status: LineCrossingStatus
    let distanceMeters: Double?
    let timeToLine: TimeInterval?
    let referencePoint: BoatReferencePoint
    let isBowOffsetApplied: Bool
    let isDegraded: Bool
    let degradedReason: LineCrossingDegradedReason?
    let bowGainToLineMeters: Double?
    let gpsDistanceToLineMeters: Double?
    let bowDistanceToLineMeters: Double?

    init(
        status: LineCrossingStatus,
        distanceMeters: Double?,
        timeToLine: TimeInterval?,
        referencePoint: BoatReferencePoint = .gps,
        isBowOffsetApplied: Bool = false,
        isDegraded: Bool = false,
        degradedReason: LineCrossingDegradedReason? = nil,
        bowGainToLineMeters: Double? = nil,
        gpsDistanceToLineMeters: Double? = nil,
        bowDistanceToLineMeters: Double? = nil
    ) {
        self.status = status
        self.distanceMeters = distanceMeters
        self.timeToLine = timeToLine
        self.referencePoint = referencePoint
        self.isBowOffsetApplied = isBowOffsetApplied
        self.isDegraded = isDegraded
        self.degradedReason = degradedReason
        self.bowGainToLineMeters = bowGainToLineMeters
        self.gpsDistanceToLineMeters = gpsDistanceToLineMeters
        self.bowDistanceToLineMeters = bowDistanceToLineMeters
    }
}
