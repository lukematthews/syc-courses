import SwiftUI

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
                    NavigationLink(value: HomeRoute.quickBearing) {
                        HomeCard(title: "Quick Bearing", subtitle: "Bearing and distance to a mark", systemImage: "location.north.line")
                    }
                    NavigationLink(value: HomeRoute.flags) {
                        HomeCard(title: "Flags", subtitle: "Numeral pennants 0-9", systemImage: "flag")
                    }
                    NavigationLink(value: HomeRoute.fixed) {
                        HomeCard(title: "Fixed Mark Courses", subtitle: "\(fixedCourses.count) bundled courses", systemImage: "list.bullet.rectangle")
                    }
                    if !laidCourses.isEmpty {
                        NavigationLink(value: HomeRoute.laid) {
                            HomeCard(title: "Laid Courses", subtitle: "\(laidCourses.count) Appendix A courses", systemImage: "triangle")
                        }
                    }
                    NavigationLink(value: HomeRoute.startAssist) {
                        HomeCard(title: "Start Assist", subtitle: "Gun time, offset, and run to SYC 4", systemImage: "timer")
                    }

                    if !recentCourses.isEmpty {
                        RecentCoursesHeader {
                            recentsStore.clear()
                        }
                        ForEach(recentCourses) { course in
                            NavigationLink(value: course) {
                                CourseCardView(course: course)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.groupedBackground)
            .navigationTitle("SYC Courses")
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .quickBearing: QuickBearingView()
                case .flags: PennantReferenceView()
                case .fixed: CourseListView(kind: .fixed)
                case .laid: CourseListView(kind: .laid)
                case .startAssist: StartAssistView()
                }
            }
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(course: course)
            }
        }
    }
}

private enum HomeRoute: Hashable {
    case quickBearing
    case flags
    case fixed
    case laid
    case startAssist
}

private struct HomeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.bold())
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
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
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
