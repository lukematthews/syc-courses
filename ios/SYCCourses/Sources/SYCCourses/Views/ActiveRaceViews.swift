import SwiftUI

struct ActiveRacePanel: View {
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    let onOpenCourse: (() -> Void)?
    let onOpenTracker: (() -> Void)?

    init(onOpenCourse: (() -> Void)? = nil, onOpenTracker: (() -> Void)? = nil) {
        self.onOpenCourse = onOpenCourse
        self.onOpenTracker = onOpenTracker
    }

    var body: some View {
        if let course = activeRaceStore.activeCourse {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.run")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.tint)
                            Text("Course \(course.courseNumber)")
                                .font(.headline.weight(.bold))
                        }
                        Text(activeRaceStore.activeMark.map { "Going to: \($0.name)" } ?? "Going to: --")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    PennantStripView(number: course.courseNumber)
                }

                HStack(spacing: 8) {
                    Button {
                        activeRaceStore.retreatMark()
                    } label: {
                        Label("Previous Mark", systemImage: "chevron.left")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .disabled(activeRaceStore.activeMarkIndex == nil || activeRaceStore.activeMarkIndex == 0)

                    Button {
                        activeRaceStore.advanceMark()
                    } label: {
                        Label("Next Mark", systemImage: "chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(activeRaceStore.activeMarkIndex == nil || activeRaceStore.activeMarkIndex == activeRaceStore.courseMarks.count - 1)

                    Spacer()

                    if let onOpenTracker {
                        Button {
                            onOpenTracker()
                        } label: {
                            Label("Map", systemImage: "map")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                    }

                    if let onOpenCourse {
                        Button {
                            onOpenCourse()
                        } label: {
                            Label("Course", systemImage: "list.bullet.rectangle")
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct ActiveCourseControlPanel: View {
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(isActiveCourse ? "Active course" : "Set active course", systemImage: isActiveCourse ? "checkmark.circle.fill" : "scope")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isActiveCourse ? .green : .primary)
                Spacer()
                if isActiveCourse {
                    Button("Clear") {
                        activeRaceStore.clearActiveCourse()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }

            if isActiveCourse {
                HStack(spacing: 8) {
                    Button {
                        activeRaceStore.retreatMark()
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(activeRaceStore.activeMarkIndex == nil || activeRaceStore.activeMarkIndex == 0)

                    Button {
                        activeRaceStore.advanceMark()
                    } label: {
                        Label("Next Mark", systemImage: "chevron.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(activeRaceStore.activeMarkIndex == nil || activeRaceStore.activeMarkIndex == activeRaceStore.courseMarks.count - 1)
                }

                if let activeMark = activeRaceStore.activeMark {
                    Text("Current: \(activeMark.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    activeRaceStore.setActiveCourse(course)
                } label: {
                    Label("Set Active Course", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private var isActiveCourse: Bool {
        activeRaceStore.activeCourseNumber == course.courseNumber
    }
}
