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
        manager.pausesLocationUpdatesAutomatically = false
        #if os(iOS)
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        #endif
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

    var navigationFix: NavigationFix? {
        guard let location else { return nil }
        let speedKnots = location.speed >= 0 ? location.speed * 1.943844 : nil
        let course = location.course >= 0 ? location.course : nil
        let accuracy = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
        return NavigationFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            sogKnots: speedKnots,
            cogDegrees: course,
            headingDegrees: nil,
            timestamp: location.timestamp,
            source: .iPhoneGPS,
            horizontalAccuracyMeters: accuracy,
            hdop: nil,
            validFix: true
        )
    }

    func snapshot(to mark: Mark) -> BearingSnapshot? {
        guard let fix = navigationFix else { return nil }
        return BearingSnapshot(fix: fix, mark: mark)
    }
}

extension BearingSnapshot {
    init(fix: NavigationFix, mark: Mark) {
        let bearing = NavigationMath.bearingTrue(
            fromLatitude: fix.latitude,
            fromLongitude: fix.longitude,
            toLatitude: mark.latitude,
            toLongitude: mark.longitude
        )
        let distance = NavigationMath.distanceNm(
            fromLatitude: fix.latitude,
            fromLongitude: fix.longitude,
            toLatitude: mark.latitude,
            toLongitude: mark.longitude
        )
        self.init(
            currentLatitude: fix.latitude,
            currentLongitude: fix.longitude,
            bearingTrue: bearing,
            distanceNm: distance,
            speedOverGroundKnots: fix.sogKnots,
            horizontalAccuracyMeters: fix.horizontalAccuracyMeters ?? (fix.hdop.map { $0 * 5 } ?? -1),
            timestamp: fix.timestamp
        )
    }
}
