import Foundation
import CoreLocation
import WidgetKit

/// Handles opt-in location sharing: permission, updates, and pushing coordinates
/// to the backend while sharing is on.
///
/// Sharing keeps working when the app is not in the foreground: with "Always"
/// access we also monitor *significant location changes*, which relaunches the
/// app in the background after a meaningful move so the partner's distance stays
/// current without anyone opening the app. With only "When In Use" the app can
/// still share, but our own position is refreshed only while the app is open.
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
        // Restore the last known coordinate so the distance is right immediately,
        // before the first fix of this launch arrives.
        if let saved = MyLocationStore.coordinate {
            currentLocation = CLLocation(latitude: saved.latitude, longitude: saved.longitude)
        }
        // Resume sharing if the user previously turned it on and access is granted.
        if wantsSharing, isAuthorized {
            isSharing = true
            startUpdates()
        }
    }

    private var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// True until the user has answered the system permission prompt.
    var needsPermissionPrompt: Bool { manager.authorizationStatus == .notDetermined }

    /// True when the distance can keep updating with the app closed. Until the
    /// user grants "Always", our own position only moves while the app is open.
    var updatesInBackground: Bool { manager.authorizationStatus == .authorizedAlways }

    /// Ask for "When In Use" access if the user hasn't decided yet. Used by the
    /// first-run priming step so both partners grant location for distance and
    /// widget features. Call this only after showing an in-app explanation.
    func requestWhenInUseIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Ask to upgrade to "Always". iOS only shows this prompt once, and only
    /// after "When In Use" was granted; it is what lets the widget's distance
    /// refresh while the app is closed.
    func requestAlwaysIfPossible() {
        guard manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestAlwaysAuthorization()
    }

    func startSharing() {
        isSharing = true
        wantsSharing = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdates()
            requestAlwaysIfPossible()
        default:
            isSharing = false
            wantsSharing = false
        }
    }

    func stopSharing() {
        isSharing = false
        wantsSharing = false
        currentLocation = nil
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        MyLocationStore.clear()
        DistanceSync.publish(km: nil)
        WidgetCenter.shared.reloadAllTimelines()
        Task { try? await APIClient.shared.stopSharingLocation() }
    }

    /// Starts the fine-grained foreground stream plus, when allowed, the
    /// significant-change stream that survives the app being suspended or
    /// terminated (iOS relaunches us in the background to deliver it).
    private func startUpdates() {
        manager.startUpdatingLocation()
        if manager.authorizationStatus == .authorizedAlways {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isSharing, isAuthorized {
            startUpdates()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            isSharing = false
            wantsSharing = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isSharing, let loc = locations.last else { return }
        currentLocation = loc
        MyLocationStore.save(loc.coordinate)
        Task {
            try? await APIClient.shared.updateLocation(
                lat: loc.coordinate.latitude,
                lng: loc.coordinate.longitude,
                accuracy: loc.horizontalAccuracy,
                mode: "live"
            )
            // Recompute against the partner's latest position and refresh the
            // widget — this also runs when iOS woke us in the background.
            await DistanceSync.refresh(myCoordinate: loc.coordinate)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient (no fix yet, airplane mode). Keep sharing on; the next
        // update or app foreground will recover.
    }
}
