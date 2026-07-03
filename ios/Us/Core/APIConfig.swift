import Foundation

enum APIConfig {
    /// Base URL of the Us backend. Debug builds talk to a local server; release
    /// builds use the deployed API.
    static var baseURL: URL {
        #if DEBUG
        // Production API — works on a real device over any network (Wi‑Fi or cellular).
        // For local backend development instead, swap to your Mac's LAN IP,
        // e.g. URL(string: "http://192.168.3.8:8080")!
        return URL(string: "https://usapi.islamov.online")!
        #else
        return URL(string: "https://usapi.islamov.online")!
        #endif
    }
}
