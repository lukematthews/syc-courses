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

                    if isOnFinalMark {
                        ActiveCourseEndControl(action: .finish, style: .prominent)
                    } else {
                        Button {
                            activeRaceStore.advanceMark()
                        } label: {
                            Label("Next Mark", systemImage: "chevron.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(activeRaceStore.activeMarkIndex == nil)
                    }

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

                ActiveCourseEndControl(action: .stop, style: .fullWidth)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var isOnFinalMark: Bool {
        guard let activeMarkIndex = activeRaceStore.activeMarkIndex,
              !activeRaceStore.courseMarks.isEmpty
        else { return false }
        return activeMarkIndex == activeRaceStore.courseMarks.count - 1
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
                    ActiveCourseEndControl(action: .stop, style: .compact)
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

                    if isOnFinalMark {
                        ActiveCourseEndControl(action: .finish, style: .prominent)
                    } else {
                        Button {
                            activeRaceStore.advanceMark()
                        } label: {
                            Label("Next Mark", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(activeRaceStore.activeMarkIndex == nil)
                    }
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
        activeRaceStore.activeCourseID == course.id
    }

    private var isOnFinalMark: Bool {
        guard isActiveCourse,
              let activeMarkIndex = activeRaceStore.activeMarkIndex,
              !activeRaceStore.courseMarks.isEmpty
        else { return false }
        return activeMarkIndex == activeRaceStore.courseMarks.count - 1
    }
}

enum ActiveCourseEndAction {
    case stop
    case finish

    var buttonTitle: String {
        switch self {
        case .stop: "Stop Course"
        case .finish: "Finish Course"
        }
    }

    var systemImage: String {
        switch self {
        case .stop: "stop.circle"
        case .finish: "checkmark.circle"
        }
    }

    func perform(on activeRaceStore: ActiveRaceStore) {
        activeRaceStore.clearActiveCourse()
    }
}

private enum ActiveCourseEndControlStyle {
    case compact
    case fullWidth
    case prominent
}

private struct ActiveCourseEndControl: View {
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    @State private var isConfirmationPresented = false
    let action: ActiveCourseEndAction
    let style: ActiveCourseEndControlStyle

    var body: some View {
        button
            .confirmationDialog(
                "Stop Course?",
                isPresented: $isConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Stop Course", role: .destructive) {
                    action.perform(on: activeRaceStore)
                }
                Button("Keep Running", role: .cancel) {}
            } message: {
                Text("This will stop navigation and background location updates.")
            }
    }

    @ViewBuilder
    private var button: some View {
        switch style {
        case .compact:
            Button("Stop Course", role: .destructive) {
                isConfirmationPresented = true
            }
            .font(.subheadline.weight(.semibold))

        case .fullWidth:
            Button(role: .destructive) {
                isConfirmationPresented = true
            } label: {
                Label(action.buttonTitle, systemImage: action.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)

        case .prominent:
            Button(role: .destructive) {
                isConfirmationPresented = true
            } label: {
                Label(action.buttonTitle, systemImage: action.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}
