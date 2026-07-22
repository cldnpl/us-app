import Foundation

/// Constants and helpers shared between the main app and the widget extension.
/// Anything in `Shared/` is compiled into both targets.
enum SharedConfig {
    /// App Group container used to share small pieces of state (widget snapshot,
    /// auth tokens for the interactive widget, partner preferences).
    static let appGroup = "group.com.claudianapolitano.us"

    /// Base URL of the Us backend. Kept in sync with the app's `APIConfig`.
    static let apiBaseURL = URL(string: "https://usapi.islamov.online")!

    /// Shared `UserDefaults` suite backed by the App Group.
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Custom URL used by the iOS 16 widget fallback to open the app and send.
    static let missYouURL = URL(string: "usapp://missyou")!

    /// TEST ONLY: enables the "0000" pairing bypass + demo data (Claudia/Elbek,
    /// Naples/Tashkent) so the app can be tested without a real partner — even on
    /// TestFlight/Release. Set to `false` before any public launch.
    static let demoMode = true
}
