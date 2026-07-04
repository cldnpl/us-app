import Foundation

enum APIConfig {
    /// Base URL of the Us backend. Shared with the widget extension via
    /// `SharedConfig` so both talk to the same server.
    ///
    /// For local backend development, temporarily point `SharedConfig.apiBaseURL`
    /// at your Mac's LAN IP, e.g. `URL(string: "http://192.168.3.8:8080")!`.
    static var baseURL: URL { SharedConfig.apiBaseURL }
}
