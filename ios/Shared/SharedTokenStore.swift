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
    private static let updatedAtKey = "shared_auth_tokens_updated_at"

    /// A complete set of credentials. Keeping the access and refresh token
    /// together avoids treating a half-written pair as a usable login when the
    /// app and widget wake at the same time.
    struct TokenPair: Equatable {
        let accessToken: String
        let refreshToken: String
        let updatedAt: Date?
    }

    static var accessToken: String? {
        get { SharedConfig.defaults?.string(forKey: accessKey) }
        set { setOrRemove(newValue, forKey: accessKey) }
    }

    static var refreshToken: String? {
        get { SharedConfig.defaults?.string(forKey: refreshKey) }
        set { setOrRemove(newValue, forKey: refreshKey) }
    }

    static var tokenPair: TokenPair? {
        guard let accessToken, !accessToken.isEmpty,
              let refreshToken, !refreshToken.isEmpty else { return nil }
        let timestamp = SharedConfig.defaults?.object(forKey: updatedAtKey) as? TimeInterval
        return TokenPair(
            accessToken: accessToken,
            refreshToken: refreshToken,
            updatedAt: timestamp.map(Date.init(timeIntervalSince1970:))
        )
    }

    /// Store a freshly issued pair as one logical update. App Group defaults
    /// are shared with the widget, so the timestamp also lets the main app
    /// recognize a pair that the widget rotated while it was not running.
    static func setTokens(accessToken: String, refreshToken: String, updatedAt: Date = Date()) {
        guard let defaults = SharedConfig.defaults else { return }
        defaults.set(accessToken, forKey: accessKey)
        defaults.set(refreshToken, forKey: refreshKey)
        defaults.set(updatedAt.timeIntervalSince1970, forKey: updatedAtKey)
    }

    static func clear() {
        SharedConfig.defaults?.removeObject(forKey: accessKey)
        SharedConfig.defaults?.removeObject(forKey: refreshKey)
        SharedConfig.defaults?.removeObject(forKey: updatedAtKey)
    }

    private static func setOrRemove(_ value: String?, forKey key: String) {
        guard let defaults = SharedConfig.defaults else { return }
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }
}
