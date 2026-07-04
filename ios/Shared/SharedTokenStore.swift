import Foundation

/// Auth tokens mirrored into the App Group so the **widget extension** can call
/// the API on the user's behalf (the interactive "I miss you" button) without
/// launching the app.
///
/// The main app's Keychain remains the source of truth; it mirrors tokens here
/// on every change (see `TokenStore`). The widget reads them and, if the access
/// token has expired, can refresh and write the rotated tokens back.
enum SharedTokenStore {
    private static let accessKey = "shared_access_token"
    private static let refreshKey = "shared_refresh_token"

    static var accessToken: String? {
        get { SharedConfig.defaults?.string(forKey: accessKey) }
        set { setOrRemove(newValue, forKey: accessKey) }
    }

    static var refreshToken: String? {
        get { SharedConfig.defaults?.string(forKey: refreshKey) }
        set { setOrRemove(newValue, forKey: refreshKey) }
    }

    static func clear() {
        SharedConfig.defaults?.removeObject(forKey: accessKey)
        SharedConfig.defaults?.removeObject(forKey: refreshKey)
    }

    private static func setOrRemove(_ value: String?, forKey key: String) {
        guard let defaults = SharedConfig.defaults else { return }
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}
