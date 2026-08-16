import ActivityKit
import SwiftUI
import WidgetKit
import SYCCourses

@main
struct SYCCoursesWidgetBundle: WidgetBundle {
    var body: some Widget {
        CourseNavigationWidget()
        CourseNavigationLiveActivity()
    }
}

struct CourseNavigationWidget: Widget {
    let kind = "CourseNavigationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CourseNavigationTimelineProvider()) { entry in
            CourseNavigationAccessoryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Active Course")
        .description("See the active mark, bearing, and distance.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

struct CourseNavigationEntry: TimelineEntry {
    let date: Date
    let snapshot: CourseNavigationWidgetSnapshot?
}

struct CourseNavigationTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CourseNavigationEntry {
        CourseNavigationEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseNavigationEntry) -> Void) {
        completion(CourseNavigationEntry(
            date: .now,
            snapshot: context.isPreview ? .preview : CourseNavigationWidgetStore.load()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseNavigationEntry>) -> Void) {
        let now = Date()
        let entry = CourseNavigationEntry(date: now, snapshot: CourseNavigationWidgetStore.load())
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(60))))
    }
}

struct CourseNavigationAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CourseNavigationEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        default:
            rectangularView
        }
    }

    private var inlineView: some View {
        Group {
            if let snapshot = entry.snapshot {
                Label {
                    Text("C\(snapshot.courseNumber) → \(snapshot.markName) · \(snapshot.bearingText) · \(snapshot.distanceText)")
                } icon: {
                    Image(systemName: "location.north.fill")
                }
            } else {
                Label("No active course", systemImage: "location.slash")
            }
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let snapshot = entry.snapshot {
                VStack(spacing: 0) {
                    Image(systemName: "location.north.fill")
                        .font(.caption2)
                    Text(snapshot.bearingCompactText)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .minimumScaleFactor(0.7)
                    Text(snapshot.distanceCompactText)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .minimumScaleFactor(0.7)
                }
            } else {
                Image(systemName: "location.slash")
            }
        }
    }

    private var rectangularView: some View {
        Group {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("C\(snapshot.courseNumber) · \(snapshot.markName)")
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(snapshot.legIndex + 1)/\(snapshot.totalLegs)")
                            .font(.caption.monospacedDigit())
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(snapshot.bearingText)
                            .font(.title3.monospacedDigit().weight(.black))
                    Text(snapshot.distanceText)
                            .font(.title3.monospacedDigit().weight(.black))
                        Spacer(minLength: 4)
                    }
                    HStack(spacing: 4) {
                        Text(snapshot.sourceText)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if snapshot.isPositionStale {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .accessibilityLabel("GPS position is stale")
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Label("No active course", systemImage: "location.slash")
                        .font(.headline)
                    Text("Set a course active in the app")
                        .font(.caption)
                }
            }
        }
    }
}

struct CourseNavigationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CourseNavigationActivityAttributes.self) { context in
            CourseNavigationLockScreenView(
                state: context.state,
                isStale: context.isStale
            )
            .activityBackgroundTint(Color(red: 0.02, green: 0.12, blue: 0.22))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("COURSE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text("\(context.state.courseNumber)")
                            .font(.title2.monospacedDigit().weight(.black))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(context.state.bearingText)
                            .font(.headline.monospacedDigit().weight(.black))
                        Text(context.state.distanceText)
                            .font(.caption.monospacedDigit().weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.markName)
                            .font(.headline.weight(.black))
                            .lineLimit(1)
                        Text(context.state.roundingText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        HStack {
                            Label("Leg \(context.state.legIndex + 1) of \(context.state.totalLegs)", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            Spacer()
                            freshnessLabel(timestamp: context.state.positionTimestamp, isStale: context.isStale)
                        }
                        Text(context.state.sourceText)
                            .foregroundStyle(context.state.isUsingFallbackPosition == true ? .orange : .secondary)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Text("C\(context.state.courseNumber)")
                    .font(.caption.weight(.black))
            } compactTrailing: {
                HStack(spacing: 3) {
                    Image(systemName: "location.north.fill")
                    Text(context.state.bearingCompactText)
                    Text(context.state.distanceCompactText)
                }
                .font(.caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Image(systemName: "location.north.fill")
            }
            .keylineTint(.cyan)
        }
    }
}

private struct CourseNavigationLockScreenView: View {
    let state: CourseNavigationActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("COURSE \(state.courseNumber)")
                    .font(.headline.weight(.black))
                Spacer()
                Text("LEG \(state.legIndex + 1) OF \(state.totalLegs)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text(state.markName)
                    .font(.title2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(state.roundingText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.cyan)
            }

            HStack(spacing: 24) {
                NavigationMetric(title: "BEARING", value: state.bearingText)
                NavigationMetric(title: "DISTANCE", value: state.distanceText)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    freshnessLabel(timestamp: state.positionTimestamp, isStale: isStale)
                    Text(state.sourceText)
                        .foregroundStyle(state.isUsingFallbackPosition == true ? .orange : .secondary)
                }
                Spacer()
                if let accuracy = state.horizontalAccuracyMeters, accuracy >= 0 {
                    Text("±\(Int(accuracy.rounded())) m")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(isStale ? .orange : .secondary)
        }
        .padding()
    }
}

private struct NavigationMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title.monospacedDigit().weight(.black))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

@ViewBuilder
private func freshnessLabel(timestamp: Date?, isStale: Bool) -> some View {
    if let timestamp {
        HStack(spacing: 4) {
            Image(systemName: isStale ? "exclamationmark.triangle.fill" : "location.fill")
            Text(timestamp, style: .relative)
        }
    } else {
        Label("Waiting for GPS", systemImage: "location.slash")
    }
}

private extension CourseNavigationWidgetSnapshot {
    static let preview = CourseNavigationWidgetSnapshot(
        courseID: "preview-course-12",
        courseNumber: 12,
        clubName: "SYC",
        markName: "SYC 6",
        roundingSide: "Starboard",
        legIndex: 2,
        totalLegs: 9,
        bearingTrue: 83,
        bearingReference: "trueNorth",
        magneticVariationDegrees: 12,
        positionSource: "NMEA2000",
        isUsingFallbackPosition: false,
        distanceNm: 1.24,
        horizontalAccuracyMeters: 8,
        positionTimestamp: .now,
        updatedAt: .now
    )

    var isPositionStale: Bool {
        guard let positionTimestamp else { return true }
        return Date().timeIntervalSince(positionTimestamp) > 30
    }
    var bearingText: String {
        (isPositionStale ? nil : bearingTrue).navigationBearingText(
            reference: bearingReference,
            variationDegrees: magneticVariationDegrees
        )
    }
    var bearingCompactText: String {
        (isPositionStale ? nil : bearingTrue).navigationBearingCompactText(
            reference: bearingReference,
            variationDegrees: magneticVariationDegrees
        )
    }
    var distanceText: String { (isPositionStale ? nil : distanceNm).navigationDistanceText }
    var distanceCompactText: String { (isPositionStale ? nil : distanceNm).navigationDistanceCompactText }
    var roundingText: String {
        roundingSide.isEmpty ? "ROUNDING NOT PUBLISHED" : "LEAVE TO \(roundingSide.uppercased())"
    }
    var sourceText: String {
        isUsingFallbackPosition == true ? "IPHONE GPS FALLBACK" : (positionSource?.uppercased() ?? "POSITION SOURCE UNKNOWN")
    }
}

private extension CourseNavigationActivityAttributes.ContentState {
    var bearingText: String {
        bearingTrue.navigationBearingText(
            reference: bearingReference,
            variationDegrees: magneticVariationDegrees
        )
    }
    var bearingCompactText: String {
        bearingTrue.navigationBearingCompactText(
            reference: bearingReference,
            variationDegrees: magneticVariationDegrees
        )
    }
    var distanceText: String { distanceNm.navigationDistanceText }
    var distanceCompactText: String { distanceNm.navigationDistanceCompactText }
    var roundingText: String {
        roundingSide.isEmpty ? "ROUNDING NOT PUBLISHED" : "LEAVE TO \(roundingSide.uppercased())"
    }
    var sourceText: String {
        isUsingFallbackPosition == true ? "IPHONE GPS FALLBACK" : (positionSource?.uppercased() ?? "POSITION SOURCE UNKNOWN")
    }
}

private extension Optional where Wrapped == Double {
    func navigationBearingText(reference: String?, variationDegrees: Double?) -> String {
        let suffix = reference == "magnetic" && variationDegrees != nil ? "M" : "T"
        guard let value = displayedBearing(reference: reference, variationDegrees: variationDegrees) else {
            return "---°\(suffix)"
        }
        return String(format: "%03.0f°%@", value.rounded(), suffix)
    }

    func navigationBearingCompactText(reference: String?, variationDegrees: Double?) -> String {
        let suffix = reference == "magnetic" && variationDegrees != nil ? "M" : "T"
        guard let value = displayedBearing(reference: reference, variationDegrees: variationDegrees) else {
            return "---°\(suffix)"
        }
        return String(format: "%03.0f°%@", value.rounded(), suffix)
    }

    private func displayedBearing(reference: String?, variationDegrees: Double?) -> Double? {
        guard let value = self else { return nil }
        let displayed = reference == "magnetic"
            ? value - (variationDegrees ?? 0)
            : value
        return displayed.truncatingRemainder(dividingBy: 360)
            .advanced(by: displayed < 0 ? 360 : 0)
            .truncatingRemainder(dividingBy: 360)
    }

    var navigationDistanceText: String {
        guard let value = self else { return "--.-- NM" }
        return value >= 10
            ? String(format: "%.1f NM", value)
            : String(format: "%.2f NM", value)
    }

    var navigationDistanceCompactText: String {
        guard let value = self else { return "--.-" }
        return value >= 10
            ? String(format: "%.1f", value)
            : String(format: "%.2f", value)
    }
}
