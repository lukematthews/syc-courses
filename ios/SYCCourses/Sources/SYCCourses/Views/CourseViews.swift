import SwiftUI

struct CourseListView: View {
    let kind: CourseKind

    private var courses: [Course] {
        switch kind {
        case .fixed: CourseDataLoader.fixedCourses()
        case .laid: CourseDataLoader.laidCourses()
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(courses) { course in
                    NavigationLink(value: course) {
                        CourseCardView(course: course)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppColors.groupedBackground)
        .navigationTitle(kind.title)
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var navigationOutputService: NavigationOutputService
    @EnvironmentObject private var recentsStore: RecentCoursesStore
    private let marks = CourseDataLoader.marks()
    let course: Course

    private var activeTargetMark: Mark? {
        guard !course.isLaidMarkCourse else { return nil }
        return course.rows.lazy.compactMap { CourseDataLoader.findMark(named: $0.mark, in: marks) }.first
    }

    private var activeWaypointState: NavigationWaypointState? {
        guard let mark = activeTargetMark,
              let snapshot = navigationDataService.snapshot(to: mark, iPhoneFix: locationService.navigationFix)
        else { return nil }
        return NavigationWaypointState(
            courseNumber: course.courseNumber,
            originName: "SYC",
            waypointName: mark.name,
            waypointID: mark.name,
            latitude: mark.latitude,
            longitude: mark.longitude,
            bearingTrue: snapshot.bearingTrue,
            distanceNm: snapshot.distanceNm,
            speedOverGroundKnots: snapshot.speedOverGroundKnots,
            timestamp: snapshot.timestamp
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    courseHeader

                    if course.isLaidMarkCourse {
                        LaidCourseInfoPanel(course: course)
                        ChartImageView(chartImage: course.chartImage)
                            .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.62)
                        LaidCourseRouteView(course: course)
                    } else {
                        CourseLineAssistPanel()
                        CourseTableView(course: course, marks: marks)
                        ChartImageView(chartImage: course.chartImage)
                            .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.62)

                        NavigationOutputCoursePanel(
                            targetMark: activeTargetMark,
                            activeWaypointState: activeWaypointState,
                            sourceSummary: navigationDataService.sourceSummary(iPhoneFix: locationService.navigationFix)
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle("")
        .onAppear {
            recentsStore.record(course)
            if !course.isLaidMarkCourse {
                locationService.startActiveUpdates()
                if navigationDataService.actisenseConfig.isConfigured,
                   navigationDataService.actisenseStatus == .disconnected {
                    Task { await navigationDataService.connectActisense() }
                }
                if navigationOutputService.settings.autoConnect,
                   navigationOutputService.canConnect,
                   !navigationOutputService.isConnected {
                    Task { await navigationOutputService.connect() }
                }
            }
        }
        .onDisappear {
            if !course.isLaidMarkCourse {
                locationService.stopActiveUpdates()
            }
        }
    }

    private var courseHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Course \(course.courseNumber)")
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(course.totalDistance)
                    .font(.title2.bold())
                courseSummaryLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PennantHoistView(number: course.courseNumber)
                .padding(.top, 4)
        }
    }

    private var courseSummaryLine: some View {
        Text(course.passInstruction + comparableCourseSuffix)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var comparableCourseSuffix: String {
        guard let note = course.comparableCourseNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty
        else { return "" }
        return ", \(note)"
    }
}

private struct LaidCourseInfoPanel: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Race Committee Boat start and finish", systemImage: "flag.checkered")
                .font(.headline.weight(.bold))
            if courseHasGate {
                Text("Pass through the gate to start the next leg.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if gateIsNotMark {
                Text("Gate is not a mark of the course.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private var courseHasGate: Bool {
        course.rows.contains { $0.mark.normalizedCourseMarkName == "gate" }
            && !gateIsNotMark
    }

    private var gateIsNotMark: Bool {
        course.courseNumber == 96
    }
}

private struct LaidCourseRouteView: View {
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Course Sequence")
                .font(.headline.weight(.bold))

            VStack(spacing: 0) {
                ForEach(Array(course.rows.enumerated()), id: \.element.id) { index, row in
                    LaidCourseRouteRow(row: row)
                    if index < course.rows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
    }
}

private struct LaidCourseRouteRow: View {
    let row: CourseLeg

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(row.mark)
                    .font(.title3.weight(.black))
                if let actionText {
                    Text(actionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var actionText: String? {
        switch row.mark.normalizedCourseMarkName {
        case "start":
            nil
        case "finish":
            nil
        case "gate":
            "Pass through to start the next leg"
        default:
            "Leave to \(row.side.lowercased())"
        }
    }
}

private struct CourseLineAssistPanel: View {
    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: HomeRoute.lineAssist(.start)) {
                CourseLineAssistButton(title: "Start", subtitle: "Line Assist", systemImage: "timer")
            }
            .buttonStyle(.plain)

            NavigationLink(value: HomeRoute.finishOptions) {
                CourseLineAssistButton(title: "Finish", subtitle: "Options", systemImage: "flag.checkered")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CourseLineAssistButton: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .contentShape(Rectangle())
    }
}

private struct NavigationOutputCoursePanel: View {
    @EnvironmentObject private var outputService: NavigationOutputService
    let targetMark: Mark?
    let activeWaypointState: NavigationWaypointState?
    let sourceSummary: NavigationSourceSummary

    private var statusText: String {
        if outputService.isSending {
            "Sending to W2K-2"
        } else if outputService.isConnected {
            "Navigation output connected"
        } else if outputService.settings.target == .disabled {
            "Navigation output disabled"
        } else {
            "Navigation output unavailable"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: outputService.isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(outputService.isConnected ? .green : .secondary)
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(outputService.isConnected ? .primary : .secondary)
                Spacer()
            }

            if let targetMark {
                Text("Active waypoint: \(targetMark.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationSourceStatusLine(summary: sourceSummary)
            } else {
                Text("No fixed mark waypoint is available for this course.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if activeWaypointState == nil, targetMark != nil {
                Text("Current GPS position is needed before output can be sent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastError = outputService.lastError {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await outputService.sendActiveWaypoint(activeWaypointState) }
            } label: {
                Label("Send to Boat", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!outputService.isConnected || activeWaypointState == nil || outputService.isSending)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

struct CourseTableView: View {
    let course: Course
    let marks: [Mark]
    private let courseBearingVariationDegrees = 12.0

    private var calculatedRows: [CalculatedCourseRow] {
        var previousMark = CourseDataLoader.findMark(named: "SYC 4", in: marks)
        return course.rows.map { row in
            guard !row.isCourseTotalRow else {
                return CalculatedCourseRow(row: row, mark: nil, bearing: nil, distanceNm: nil)
            }

            let mark = resolvedMark(for: row.mark)
            let bearing: Double?
            let distanceNm: Double?
            if row.isPassThroughRow {
                bearing = nil
                distanceNm = nil
            } else if let previousMark, let mark {
                let trueBearing = NavigationMath.bearingTrue(
                    fromLatitude: previousMark.latitude,
                    fromLongitude: previousMark.longitude,
                    toLatitude: mark.latitude,
                    toLongitude: mark.longitude
                )
                bearing = NavigationMath.magneticBearing(
                    trueBearing: trueBearing,
                    variationDegrees: courseBearingVariationDegrees
                )
                distanceNm = NavigationMath.distanceNm(
                    fromLatitude: previousMark.latitude,
                    fromLongitude: previousMark.longitude,
                    toLatitude: mark.latitude,
                    toLongitude: mark.longitude
                )
            } else {
                bearing = nil
                distanceNm = nil
            }

            if let mark, !row.isPassThroughRow {
                previousMark = mark
            }

            return CalculatedCourseRow(row: row, mark: mark, bearing: bearing, distanceNm: distanceNm)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TableHeader("Mark")
                TableHeader("Side")
                TableHeader("Bearing")
                TableHeader("Dist")
            }
            .padding(.vertical, 10)
            .background(.secondary.opacity(0.12))

            ForEach(calculatedRows) { calculatedRow in
                if let mark = calculatedRow.mark, !calculatedRow.row.isStartOrFinishRow {
                    NavigationLink {
                        MarkDetailView(mark: mark)
                    } label: {
                        CourseRowView(calculatedRow: calculatedRow, tappable: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    CourseRowView(calculatedRow: calculatedRow, tappable: false)
                }
                Divider()
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func resolvedMark(for name: String) -> Mark? {
        if name.normalizedCourseMarkName == "start" || name.normalizedCourseMarkName == "finish" {
            return CourseDataLoader.findMark(named: "SYC 4", in: marks)
        }
        return CourseDataLoader.findMark(named: name, in: marks)
    }
}

private struct CourseRowView: View {
    let calculatedRow: CalculatedCourseRow
    let tappable: Bool

    private var row: CourseLeg {
        calculatedRow.row
    }

    var body: some View {
        HStack {
            Text(row.mark)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.side)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(calculatedRow.bearingText)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(calculatedRow.distanceText)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct CalculatedCourseRow: Identifiable {
    let row: CourseLeg
    let mark: Mark?
    let bearing: Double?
    let distanceNm: Double?

    var id: UUID {
        row.id
    }

    var bearingText: String {
        guard let bearing else {
            return row.isCourseTotalRow ? "" : row.bearing
        }
        return String(format: "%03.0f", NavigationMath.normalizeDegrees(bearing).rounded())
    }

    var distanceText: String {
        guard let distanceNm else {
            return row.isCourseTotalRow ? row.distance : row.distance
        }
        return String(format: "%.2f", distanceNm)
    }
}

private extension CourseLeg {
    var isCourseTotalRow: Bool {
        let name = mark.normalizedCourseMarkName
        return name == "total" || name == "sub-total" || name == "subtotal"
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

private extension Course {
    var isLaidMarkCourse: Bool {
        courseNumber >= 80
    }
}

private extension String {
    var normalizedCourseMarkName: String {
        replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct TableHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }
}
