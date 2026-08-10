import Foundation
import CoreLocation

/// The device owner's own last known coordinate, mirrored into the App Group.
///
/// The widget cannot ask the app where you are, and it may run while the app is
/// not, so the app writes every fix here. The widget reads it to compute the
/// distance on its own.
enum MyLocationStore {
    private static let latKey = "my_location_lat"
    private static let lngKey = "my_location_lng"
    private static let atKey = "my_location_updated_at"

    static var coordinate: CLLocationCoordinate2D? {
        guard let defaults = SharedConfig.defaults,
              defaults.object(forKey: latKey) != nil,
              defaults.object(forKey: lngKey) != nil else { return nil }
        return CLLocationCoordinate2D(latitude: defaults.double(forKey: latKey),
                                      longitude: defaults.double(forKey: lngKey))
    }

    static var updatedAt: Date? {
        SharedConfig.defaults?.object(forKey: atKey) as? Date
    }

    static func save(_ coordinate: CLLocationCoordinate2D) {
        guard let defaults = SharedConfig.defaults else { return }
        defaults.set(coordinate.latitude, forKey: latKey)
        defaults.set(coordinate.longitude, forKey: lngKey)
        defaults.set(Date(), forKey: atKey)
    }

    static func clear() {
        guard let defaults = SharedConfig.defaults else { return }
        [latKey, lngKey, atKey].forEach(defaults.removeObject(forKey:))
    }
}

/// Partner location as returned by `GET /v1/location`, decoded without the
/// app's `APIClient` so the widget can fetch it too.
struct SharedPartnerLocation: Decodable {
    let sharing: Bool
    let lat: Double?
    let lng: Double?
    let partnerName: String?

    var coordinate: CLLocationCoordinate2D? {
        guard sharing, let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

/// Keeps the distance between the two partners fresh — from the app *and* from
/// the widget extension.
///
/// This is what makes the distance update on its own: the widget's timeline
/// provider calls `refresh()` on every reload, so it fetches the partner's
/// current position itself instead of waiting for someone to open the app.
enum DistanceSync {
    /// Fetches the partner's position, computes the distance from `myCoordinate`
    /// (falling back to the last coordinate the app stored), writes the widget
    /// snapshot and returns the distance in kilometres — nil when either side is
    /// not sharing.
    @discardableResult
    static func refresh(myCoordinate: CLLocationCoordinate2D? = nil) async -> Double? {
        let mine = myCoordinate ?? MyLocationStore.coordinate
        guard let response = await SharedAPI.request("/v1/location"), response.isSuccess,
              let partner = try? JSONDecoder().decode(SharedPartnerLocation.self, from: response.data)
        else {
            return WidgetStore.load()?.distanceKm
        }
        let km = distanceKm(mine, partner.coordinate)
        publish(km: km, partnerName: partner.partnerName)
        return km
    }

    /// Distance in kilometres between two coordinates, nil if either is missing.
    static func distanceKm(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Double? {
        guard let a, let b else { return nil }
        return CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) / 1000.0
    }

    /// Writes the distance into the shared snapshot, preserving everything else
    /// the app published (names, days together).
    static func publish(km: Double?, partnerName: String? = nil) {
        let existing = WidgetStore.load()
        let name = partnerName.flatMap { $0.isEmpty ? nil : $0 } ?? existing?.partnerName ?? ""
        WidgetStore.save(WidgetSnapshot(
            partnerName: name,
            daysTogether: existing?.daysTogether,
            updatedAt: Date(),
            myName: existing?.myName,
            distanceKm: km
        ))
    }
}
