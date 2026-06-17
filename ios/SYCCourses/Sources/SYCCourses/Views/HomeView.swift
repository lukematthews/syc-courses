import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @EnvironmentObject private var recentsStore: RecentCoursesStore
    private let fixedCourses = CourseDataLoader.fixedCourses()
    private let laidCourses = CourseDataLoader.laidCourses()

    var recentCourses: [Course] {
        recentsStore.recentCourseNumbers.compactMap { number in
            (fixedCourses + laidCourses).first { $0.courseNumber == number }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    HomeHeader()

                    NavigationLink(value: HomeRoute.quickBearing) {
                        HomeCard(title: "Quick Bearing", subtitle: "Bearing and distance to a mark", systemImage: "location.north.line")
                    }
                    NavigationLink(value: HomeRoute.flags) {
                        HomeCard(title: "Flags", subtitle: "Numeral pennants 0-9", systemImage: "flag")
                    }
                    NavigationLink(value: HomeRoute.fixed) {
                        HomeCard(title: "Fixed Mark Courses", subtitle: "\(fixedCourses.count) courses", systemImage: "list.bullet.rectangle")
                    }
                    if !laidCourses.isEmpty {
                        NavigationLink(value: HomeRoute.laid) {
                            HomeCard(title: "Laid Courses", subtitle: "\(laidCourses.count) courses", systemImage: "triangle")
                        }
                    }
                    NavigationLink(value: HomeRoute.lineAssist(.start)) {
                        HomeCard(title: "Line Assist", subtitle: "Start and finish line crossing", systemImage: "timer")
                    }
                    NavigationLink(value: HomeRoute.navigationOutput) {
                        HomeCard(title: "Instruments", subtitle: "Boat communication with Actisense W2K-2", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    if !recentCourses.isEmpty {
                        RecentCoursesHeader {
                            recentsStore.clear()
                        }
                        ForEach(recentCourses) { course in
                            NavigationLink(value: course) {
                                CourseCardView(course: course)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(HomeColors.background)
            .navigationTitle("")
            .homeNavigationChrome()
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .quickBearing: QuickBearingView()
                case .flags: PennantReferenceView()
                case .fixed: CourseListView(kind: .fixed)
                case .laid: CourseListView(kind: .laid)
                case let .lineAssist(mode): StartAssistView(initialMode: mode)
                case .finishOptions: FinishOptionsView()
                case .navigationOutput: NavigationOutputSettingsView()
                }
            }
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(course: course)
            }
        }
    }
}

private struct HomeHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AppIconImage(size: 54, cornerRadius: 12)
            Text("SYC Courses")
                .font(.largeTitle.bold())
                .foregroundStyle(HomeColors.navy)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

private struct AppIconImage: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    init(size: CGFloat = 88, cornerRadius: CGFloat = 20) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        #if canImport(UIKit)
        if let url = Bundle.module.url(forResource: "app-icon", withExtension: "png"),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        }
        #else
        EmptyView()
        #endif
    }
}

enum HomeRoute: Hashable {
    case quickBearing
    case flags
    case fixed
    case laid
    case lineAssist(LineMode)
    case finishOptions
    case navigationOutput
}

private struct FinishOptionsView: View {
    private let finishMark = CourseDataLoader.findMark(named: "SYC 4")!

    var body: some View {
        List {
            NavigationLink(value: HomeRoute.lineAssist(.finish)) {
                FinishOptionRow(
                    title: "Line Crossing",
                    subtitle: "Predict crossing the SYC Tower ↔ SYC 4 finish line",
                    systemImage: "timer"
                )
            }

            NavigationLink {
                MarkDetailView(mark: finishMark)
            } label: {
                FinishOptionRow(
                    title: "Bearing to SYC 4",
                    subtitle: "Bearing, distance, and time to the finish mark",
                    systemImage: "location.north.line"
                )
            }
        }
        .navigationTitle("Finish")
    }
}

private struct FinishOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(.vertical, 6)
    }
}

private struct HomeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .background(.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(HomeColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private enum HomeColors {
    static let navy = Color(red: 0.02, green: 0.12, blue: 0.28)
    static let background = Color(red: 0.90, green: 0.93, blue: 0.96)
    static let card = Color(red: 0.99, green: 0.995, blue: 1.0)
}

private struct RecentCoursesHeader: View {
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text("Recently Viewed")
                .font(.headline)
            Spacer()
            Button("Clear...") {
                onClear()
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

private extension View {
    @ViewBuilder
    func homeNavigationChrome() -> some View {
        #if canImport(UIKit)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
