import CoreLocation
import MapKit
import SwiftUI

struct RaceTrackerView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var raceTrackStore: RaceTrackStore
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
                if trackCoordinates.count > 1 {
                    MapPolyline(coordinates: trackCoordinates)
                        .stroke(.blue, lineWidth: 4)
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
                if trackPoints.isEmpty {
                    ContentUnavailableView("No track recorded", systemImage: "map", description: Text("Start recording to draw the race path."))
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(spacing: 14) {
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
        guard let track = raceTrackStore.currentTrack else { return }
        scrubOffset = track.duration
        if let coordinate = track.points.first?.coordinate {
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
