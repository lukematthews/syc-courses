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
        course.rows.lazy.compactMap { CourseDataLoader.findMark(named: $0.mark, in: marks) }.first
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

                    CourseTableView(course: course, marks: marks)

                    ChartImageView(chartImage: course.chartImage)
                        .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.62)

                    NavigationOutputCoursePanel(
                        targetMark: activeTargetMark,
                        activeWaypointState: activeWaypointState,
                        sourceSummary: navigationDataService.sourceSummary(iPhoneFix: locationService.navigationFix)
                    )
                }
                .padding()
            }
        }
        .navigationTitle("")
        .onAppear {
            recentsStore.record(course)
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
        .onDisappear {
            locationService.stopActiveUpdates()
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

            ForEach(course.rows) { row in
                if let mark = CourseDataLoader.findMark(named: row.mark, in: marks) {
                    NavigationLink {
                        MarkDetailView(mark: mark)
                    } label: {
                        CourseRowView(row: row, tappable: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    CourseRowView(row: row, tappable: false)
                }
                Divider()
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

private struct CourseRowView: View {
    let row: CourseLeg
    let tappable: Bool

    var body: some View {
        HStack {
            Text(row.mark)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.side)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.bearing)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(row.distance)
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
