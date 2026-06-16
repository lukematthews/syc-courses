import CoreLocation
import Foundation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
    }

    func requestLocation() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func startActiveUpdates() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func stopActiveUpdates() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func snapshot(to mark: Mark) -> BearingSnapshot? {
        guard let location else { return nil }
        let bearing = NavigationMath.bearingTrue(
            fromLatitude: location.coordinate.latitude,
            fromLongitude: location.coordinate.longitude,
            toLatitude: mark.latitude,
            toLongitude: mark.longitude
        )
        let distance = NavigationMath.distanceNm(
            fromLatitude: location.coordinate.latitude,
            fromLongitude: location.coordinate.longitude,
            toLatitude: mark.latitude,
            toLongitude: mark.longitude
        )
        let speedKnots = location.speed >= 0 ? location.speed * 1.943844 : nil
        return BearingSnapshot(
            currentLatitude: location.coordinate.latitude,
            currentLongitude: location.coordinate.longitude,
            bearingTrue: bearing,
            distanceNm: distance,
            speedOverGroundKnots: speedKnots,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
    }
}
