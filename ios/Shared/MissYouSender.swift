import Foundation

/// Sends an "I miss you" nudge to the partner using the shared auth tokens.
///
/// Usable from both the app and the **widget extension** — the latter lets the
/// interactive widget button fire the nudge in the background without launching
/// the app. Self-contained (no dependency on the app's `APIClient`) so it can
/// compile into the extension.
enum MissYouSender {
    /// Posts the nudge, refreshing the access token once if it has expired.
    /// Returns `true` on success.
    @discardableResult
    static func send() async -> Bool {
        await post(retryOn401: true)
    }

    private static func post(retryOn401: Bool) async -> Bool {
        guard let token = SharedTokenStore.accessToken else { return false }
        var req = URLRequest(url: SharedConfig.apiBaseURL.appendingPathComponent("/v1/miss-you"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: req),
              let code = (response as? HTTPURLResponse)?.statusCode else { return false }

        if code == 401 && retryOn401 {
            return await refresh() ? await post(retryOn401: false) : false
        }
        return (200..<300).contains(code)
    }

    private static func refresh() async -> Bool {
        guard let rt = SharedTokenStore.refreshToken else { return false }
        var req = URLRequest(url: SharedConfig.apiBaseURL.appendingPathComponent("/v1/auth/refresh"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": rt])

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["accessToken"] as? String else { return false }

        SharedTokenStore.accessToken = access
        if let newRefresh = json["refreshToken"] as? String { SharedTokenStore.refreshToken = newRefresh }
        return true
    }
}
