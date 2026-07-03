import Foundation
import CoreLocation

/// Handles opt-in location sharing: permission, updates, and pushing coordinates
/// to the backend while sharing is on. Sharing is foreground-only in this version.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isSharing = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        authorizationStatus = manager.authorizationStatus
    }

    func startSharing() {
        isSharing = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            isSharing = false
        }
    }

    func stopSharing() {
        isSharing = false
        manager.stopUpdatingLocation()
        Task { try? await APIClient.shared.stopSharingLocation() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isSharing, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isSharing, let loc = locations.last else { return }
        Task {
            try? await APIClient.shared.updateLocation(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                accuracy: loc.horizontalAccuracy,
                mode: "live"
            )
        }
    }
}
