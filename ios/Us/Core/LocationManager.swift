import Foundation
import CoreLocation

/// Handles opt-in location sharing: permission, updates, and pushing coordinates
/// to the backend while sharing is on. Sharing is foreground-only in this version.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isSharing = false
    /// The device's latest coordinate (only updated while sharing), used to
    /// compute the distance to the partner on the Home screen.
    @Published var currentLocation: CLLocation?

    /// Persisted so sharing resumes automatically on the next launch.
    private static let wantsSharingKey = "wantsLocationSharing"
    private var wantsSharing: Bool {
        get { UserDefaults.standard.bool(forKey: Self.wantsSharingKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.wantsSharingKey) }
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        authorizationStatus = manager.authorizationStatus
        // Resume sharing if the user previously turned it on and access is granted.
        if wantsSharing, authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            isSharing = true
            manager.startUpdatingLocation()
        }
    }

    /// True until the user has answered the system permission prompt.
    var needsPermissionPrompt: Bool { manager.authorizationStatus == .notDetermined }

    /// Ask for "When In Use" access if the user hasn't decided yet. Used by the
    /// first-run priming step so both partners grant location for distance and
    /// widget features. Call this only after showing an in-app explanation.
    func requestWhenInUseIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startSharing() {
        isSharing = true
        wantsSharing = true
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
        wantsSharing = false
        currentLocation = nil
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
        currentLocation = loc
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
