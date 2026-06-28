import Combine
import CoreLocation
import Foundation

final class RaceTrackStore: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var currentTrack: SavedRaceTrack?
    @Published private(set) var recentTracks: [SavedRaceTrack] = []

    private let recentTracksKey = "recentRaceTracks"
    private let maxRecentTracks = 6
    private let defaults: UserDefaults
    private weak var locationService: LocationService?
    private var locationSubscription: AnyCancellable?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentTracks = Self.loadRecentTracks(from: defaults, key: recentTracksKey)
    }

    func configure(locationService: LocationService) {
        guard self.locationService !== locationService else { return }
        self.locationService = locationService
        locationSubscription = locationService.$location
            .compactMap { $0 }
            .sink { [weak self] location in
                self?.append(location)
            }
    }

    func startRecording() {
        if currentTrack == nil {
            let startDate = locationService?.location?.timestamp ?? Date()
            currentTrack = SavedRaceTrack(id: UUID(), startedAt: startDate, name: nil, endedAt: startDate, points: [])
        }

        isRecording = true
        if let location = locationService?.location {
            append(location)
        }
        locationService?.startActiveUpdates()
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        locationService?.stopActiveUpdates()
        saveCurrentTrack()
    }

    func resetRecording() {
        stopRecording()
        currentTrack = nil
    }

    func load(_ track: SavedRaceTrack) {
        if isRecording {
            stopRecording()
        }
        currentTrack = track
    }

    func clearRecentTracks() {
        recentTracks = []
        defaults.removeObject(forKey: recentTracksKey)
    }

    func rename(_ track: SavedRaceTrack, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedName = trimmedName.isEmpty ? nil : trimmedName

        if var currentTrack, currentTrack.id == track.id {
            currentTrack.name = savedName
            self.currentTrack = currentTrack
        }

        guard let index = recentTracks.firstIndex(where: { $0.id == track.id }) else { return }
        recentTracks[index].name = savedName
        persistRecentTracks()
    }

    func delete(_ track: SavedRaceTrack) {
        recentTracks.removeAll { $0.id == track.id }
        persistRecentTracks()

        if currentTrack?.id == track.id {
            currentTrack = nil
        }
    }

    private func append(_ location: CLLocation) {
        guard isRecording else { return }
        guard location.horizontalAccuracy >= 0 else { return }

        if currentTrack == nil {
            currentTrack = SavedRaceTrack(
                id: UUID(),
                startedAt: location.timestamp,
                name: nil,
                endedAt: location.timestamp,
                points: []
            )
        }

        guard var track = currentTrack else { return }
        if track.points.last?.timestamp == location.timestamp { return }

        let point = RaceTrackPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp
        )
        track.points.append(point)
        track.endedAt = location.timestamp
        currentTrack = track
    }

    private func saveCurrentTrack() {
        guard let track = currentTrack, !track.points.isEmpty else { return }
        recentTracks.removeAll { $0.id == track.id }
        recentTracks.insert(track, at: 0)
        recentTracks = Array(recentTracks.prefix(maxRecentTracks))
        persistRecentTracks()
    }

    private func persistRecentTracks() {
        guard let data = try? JSONEncoder().encode(recentTracks) else { return }
        defaults.set(data, forKey: recentTracksKey)
    }

    private static func loadRecentTracks(from defaults: UserDefaults, key: String) -> [SavedRaceTrack] {
        guard let data = defaults.data(forKey: key),
              let tracks = try? JSONDecoder().decode([SavedRaceTrack].self, from: data)
        else { return [] }
        return tracks
    }
}
