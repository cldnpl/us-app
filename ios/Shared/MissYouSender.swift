import Foundation

/// Sends an "I miss you" nudge to the partner using the shared auth tokens.
///
/// Usable from both the app and the **widget extension** — the latter lets the
/// interactive widget button fire the nudge in the background without launching
/// the app. Built on `SharedAPI` (no dependency on the app's `APIClient`) so it
/// compiles into the extension.
enum MissYouSender {
    /// Posts the nudge, refreshing the access token once if it has expired.
    /// Returns `true` on success.
    @discardableResult
    static func send() async -> Bool {
        await SharedAPI.request("/v1/miss-you", method: "POST")?.isSuccess ?? false
    }
}
