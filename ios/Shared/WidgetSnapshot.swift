import Foundation

/// Snapshot the app writes to the shared App Group container for the widget to read.
struct WidgetSnapshot: Codable {
    var partnerName: String
    var daysTogether: Int?
    var updatedAt: Date
    /// The user's own name, for the distance widget ("You ──♥── Alex").
    var myName: String?
    /// Distance between the two partners in kilometres, when both are sharing.
    var distanceKm: Double?
}

/// Shared storage between the app and the widget (App Group).
enum WidgetStore {
    static let appGroup = SharedConfig.appGroup
    private static let key = "widget_snapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return nil }
        return snapshot
    }
}
