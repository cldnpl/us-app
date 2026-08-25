import Foundation

/// Minimal authenticated HTTP client usable from **both** the app and the
/// widget extension (anything in `Shared/` compiles into both targets).
///
/// It deliberately does not depend on the app's `APIClient`: the widget has to
/// be able to talk to the backend on its own — that is what lets the distance
/// widget refresh without the app ever being opened. Tokens come from the App
/// Group mirror (`SharedTokenStore`); an expired access token is refreshed once
/// and the rotated pair is written back for the app to pick up.
enum SharedAPI {
    struct Response {
        let status: Int
        let data: Data
        var isSuccess: Bool { (200..<300).contains(status) }
    }

    /// Performs an authenticated request, refreshing the access token once on 401.
    /// Returns nil when there is no session or the network failed outright.
    static func request(_ path: String,
                        method: String = "GET",
                        body: [String: Any]? = nil) async -> Response? {
        await perform(path, method: method, body: body, retryOn401: true)
    }

    private static func perform(_ path: String,
                                method: String,
                                body: [String: Any]?,
                                retryOn401: Bool) async -> Response? {
        guard let token = SharedTokenStore.accessToken else { return nil }
        var req = URLRequest(url: SharedConfig.apiBaseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let status = (response as? HTTPURLResponse)?.statusCode else { return nil }

        if status == 401 && retryOn401 {
            guard await refresh() else { return Response(status: status, data: data) }
            return await perform(path, method: method, body: body, retryOn401: false)
        }
        return Response(status: status, data: data)
    }

    /// Exchanges the refresh token for a new pair and mirrors it back to the
    /// App Group so the app and the widget stay on the same session.
    @discardableResult
    static func refresh() async -> Bool {
        guard let rt = SharedTokenStore.refreshToken else { return false }
        var req = URLRequest(url: SharedConfig.apiBaseURL.appendingPathComponent("/v1/auth/refresh"))
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": rt])

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["accessToken"] as? String else { return false }

        guard let newRefresh = json["refreshToken"] as? String, !newRefresh.isEmpty else { return false }
        SharedTokenStore.setTokens(accessToken: access, refreshToken: newRefresh)
        return true
    }
}
