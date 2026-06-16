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
    @EnvironmentObject private var recentsStore: RecentCoursesStore
    private let marks = CourseDataLoader.marks()
    let course: Course

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        PennantStripView(number: course.courseNumber)
                        Text(course.totalDistance)
                            .font(.title2.bold())
                        Text(course.passInstruction)
                            .foregroundStyle(.secondary)
                        if let note = course.comparableCourseNote {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    CourseTableView(course: course, marks: marks)

                    Text("Chart")
                        .font(.title3.bold())
                    ChartImageView(chartImage: course.chartImage)
                        .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.62)
                }
                .padding()
            }
        }
        .navigationTitle("Course \(course.courseNumber)")
        .onAppear {
            recentsStore.record(course)
        }
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
