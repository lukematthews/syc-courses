import CoreLocation
import MapKit
import SwiftUI

struct RaceTrackerView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var raceTrackStore: RaceTrackStore
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var scrubOffset: TimeInterval = 0
    @State private var hasScrubbed = false

    private var trackPoints: [RaceTrackPoint] {
        raceTrackStore.currentTrack?.points ?? []
    }

    private var trackCoordinates: [CLLocationCoordinate2D] {
        trackPoints.map(\.coordinate)
    }

    private var trackDuration: TimeInterval {
        RaceTrackMath.duration(for: trackPoints) ?? 0
    }

    private var scrubberUpperBound: Double {
        max(1, trackDuration)
    }

    private var avatarCoordinate: CLLocationCoordinate2D? {
        RaceTrackMath.coordinate(at: min(scrubOffset, trackDuration), in: trackPoints)
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                if activeRaceStore.courseCoordinates.count > 1 {
                    MapPolyline(coordinates: activeRaceStore.courseCoordinates)
                        .stroke(.cyan.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [8, 6]))
                }

                if trackCoordinates.count > 1 {
                    MapPolyline(coordinates: trackCoordinates)
                        .stroke(.blue, lineWidth: 4)
                }

                ForEach(activeRaceStore.courseMarks.filter { $0.id != activeRaceStore.activeMarkID }) { mark in
                    Annotation(mark.name, coordinate: mark.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 22, height: 22)
                            Circle()
                                .stroke(.cyan, lineWidth: 3)
                                .frame(width: 22, height: 22)
                            Circle()
                                .fill(.cyan)
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                if let activeMark = activeRaceStore.activeMark {
                    Annotation(activeMark.name, coordinate: activeMark.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 28, height: 28)
                            Circle()
                                .stroke(.orange, lineWidth: 4)
                                .frame(width: 28, height: 28)
                            Image(systemName: "scope")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                if let avatarCoordinate {
                    Annotation("Track position", coordinate: avatarCoordinate) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 2)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .overlay {
                if trackPoints.isEmpty && !activeRaceStore.isCourseActive {
                    ContentUnavailableView("No track recorded", systemImage: "map", description: Text("Start recording to draw the race path."))
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(spacing: 14) {
                RaceTrackerActiveCoursePanel()

                HStack(spacing: 10) {
                    Button {
                        raceTrackStore.startRecording()
                        hasScrubbed = false
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(raceTrackStore.isRecording)

                    Button {
                        raceTrackStore.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!raceTrackStore.isRecording)

                    Button(role: .destructive) {
                        raceTrackStore.resetRecording()
                        scrubOffset = 0
                        hasScrubbed = false
                        cameraPosition = .automatic
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(trackPoints.isEmpty && !raceTrackStore.isRecording)
                }

                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { min(scrubOffset, scrubberUpperBound) },
                            set: { newValue in
                                scrubOffset = min(newValue, trackDuration)
                                hasScrubbed = true
                            }
                        ),
                        in: 0...scrubberUpperBound
                    )
                    .disabled(trackDuration <= 0)

                    HStack {
                        Text(AppFormatters.duration(scrubOffset))
                        Spacer()
                        Text(AppFormatters.duration(trackDuration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Label(statusText, systemImage: raceTrackStore.isRecording ? "record.circle" : "pause.circle")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(.background)
        }
        .navigationTitle("Race Tracker")
        .raceTrackerNavigationChrome()
        .onAppear {
            locationService.requestLocation()
            syncViewToCurrentTrack()
        }
        .onReceive(raceTrackStore.$currentTrack) { track in
            guard let track else {
                scrubOffset = 0
                return
            }
            if !hasScrubbed || !raceTrackStore.isRecording {
                scrubOffset = track.duration
            }
            if track.points.count == 1 {
                moveCamera(to: track.points[0].coordinate)
            }
        }
    }

    private var statusText: String {
        if raceTrackStore.isRecording { return "Recording" }
        return trackPoints.isEmpty ? "Ready" : "Stopped"
    }

    private func syncViewToCurrentTrack() {
        if let track = raceTrackStore.currentTrack {
            scrubOffset = track.duration
            if let coordinate = track.points.first?.coordinate {
                moveCamera(to: coordinate)
            }
        } else if let coordinate = activeRaceStore.courseCoordinates.first {
            moveCamera(to: coordinate)
        }
    }

    private func moveCamera(to coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }
}

private struct RaceTrackerActiveCoursePanel: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore

    private var snapshot: BearingSnapshot? {
        guard let activeMark = activeRaceStore.activeMark else { return nil }
        return navigationDataService.snapshot(to: activeMark, iPhoneFix: locationService.navigationFix)
    }

    var body: some View {
        if let course = activeRaceStore.activeCourse {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Active Course")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Course \(course.courseNumber)")
                            .font(.headline.weight(.bold))
                        Text(activeRaceStore.activeMark.map { "Active mark: \($0.name)" } ?? "No active mark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        RaceTrackerMetricPill(title: "BTW", value: snapshot.map { AppFormatters.bearing($0.bearingTrue) } ?? "--")
                        RaceTrackerMetricPill(title: "DTW", value: snapshot.map { AppFormatters.distanceNm($0.distanceNm) } ?? "--")
                    }
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
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct RaceTrackerMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(minWidth: 76, alignment: .trailing)
    }
}

private extension View {
    @ViewBuilder
    func raceTrackerNavigationChrome() -> some View {
        #if canImport(UIKit)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
