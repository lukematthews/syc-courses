import Foundation

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

public struct CourseNavigationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let courseNumber: Int
        public let markName: String
        public let roundingSide: String
        public let legIndex: Int
        public let totalLegs: Int
        public let bearingTrue: Double?
        public let distanceNm: Double?
        public let horizontalAccuracyMeters: Double?
        public let positionTimestamp: Date?

        public init(
            courseNumber: Int,
            markName: String,
            roundingSide: String,
            legIndex: Int,
            totalLegs: Int,
            bearingTrue: Double?,
            distanceNm: Double?,
            horizontalAccuracyMeters: Double?,
            positionTimestamp: Date?
        ) {
            self.courseNumber = courseNumber
            self.markName = markName
            self.roundingSide = roundingSide
            self.legIndex = legIndex
            self.totalLegs = totalLegs
            self.bearingTrue = bearingTrue
            self.distanceNm = distanceNm
            self.horizontalAccuracyMeters = horizontalAccuracyMeters
            self.positionTimestamp = positionTimestamp
        }
    }

    public let courseID: String
    public let clubName: String

    public init(courseID: String, clubName: String) {
        self.courseID = courseID
        self.clubName = clubName
    }
}
#endif

public struct CourseNavigationWidgetSnapshot: Codable, Hashable {
    public let courseID: String
    public let courseNumber: Int
    public let clubName: String
    public let markName: String
    public let roundingSide: String
    public let legIndex: Int
    public let totalLegs: Int
    public let bearingTrue: Double?
    public let distanceNm: Double?
    public let horizontalAccuracyMeters: Double?
    public let positionTimestamp: Date?
    public let updatedAt: Date

    public init(
        courseID: String,
        courseNumber: Int,
        clubName: String,
        markName: String,
        roundingSide: String,
        legIndex: Int,
        totalLegs: Int,
        bearingTrue: Double?,
        distanceNm: Double?,
        horizontalAccuracyMeters: Double?,
        positionTimestamp: Date?,
        updatedAt: Date
    ) {
        self.courseID = courseID
        self.courseNumber = courseNumber
        self.clubName = clubName
        self.markName = markName
        self.roundingSide = roundingSide
        self.legIndex = legIndex
        self.totalLegs = totalLegs
        self.bearingTrue = bearingTrue
        self.distanceNm = distanceNm
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.positionTimestamp = positionTimestamp
        self.updatedAt = updatedAt
    }
}

public enum CourseNavigationWidgetStore {
    private static let snapshotKey = "activeCourseNavigationSnapshot"
    private static let widgetBundleSuffix = ".navigation-widget"

    public static func appGroupIdentifier(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String? {
        guard var bundleIdentifier, !bundleIdentifier.isEmpty else { return nil }
        if bundleIdentifier.hasSuffix(widgetBundleSuffix) {
            bundleIdentifier.removeLast(widgetBundleSuffix.count)
        }
        return "group.\(bundleIdentifier)"
    }

    public static func load() -> CourseNavigationWidgetSnapshot? {
        guard let defaults = sharedDefaults(),
              let data = defaults.data(forKey: snapshotKey)
        else { return nil }
        return try? JSONDecoder().decode(CourseNavigationWidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: CourseNavigationWidgetSnapshot?) {
        guard let defaults = sharedDefaults() else { return }
        guard let snapshot else {
            defaults.removeObject(forKey: snapshotKey)
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    private static func sharedDefaults() -> UserDefaults? {
        guard let identifier = appGroupIdentifier() else { return nil }
        return UserDefaults(suiteName: identifier)
    }
}
