import Foundation
import Security

/// Minimal Keychain wrapper for storing auth tokens securely.
enum Keychain {
    private static let service = "com.claudianapolitano.us.tokens"

    static func set(_ value: String?, for key: String) {
        delete(key)
        guard let value, let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Access + refresh token storage.
///
/// The Keychain is the source of truth. Tokens are also mirrored into the App
/// Group (`SharedTokenStore`) so the widget extension can send "I miss you"
/// on the user's behalf without launching the app.
enum TokenStore {
    private static let updatedAtKey = "auth_tokens_updated_at"

    static var accessToken: String? {
        get { Keychain.get("access") }
        set { Keychain.set(newValue, for: "access"); SharedTokenStore.accessToken = newValue }
    }
    static var refreshToken: String? {
        get { Keychain.get("refresh") }
        set { Keychain.set(newValue, for: "refresh"); SharedTokenStore.refreshToken = newValue }
    }

    /// Persist a newly-issued credential pair in both stores. Callers must use
    /// this instead of updating the two tokens independently, because the
    /// widget is a second process that can observe the App Group at any time.
    static func save(accessToken: String, refreshToken: String) {
        let updatedAt = Date()
        Keychain.set(accessToken, for: "access")
        Keychain.set(refreshToken, for: "refresh")
        Keychain.set(String(updatedAt.timeIntervalSince1970), for: updatedAtKey)
        SharedTokenStore.setTokens(accessToken: accessToken, refreshToken: refreshToken, updatedAt: updatedAt)
    }

    static func clear() {
        Keychain.delete("access")
        Keychain.delete("refresh")
        Keychain.delete(updatedAtKey)
        SharedTokenStore.clear()
    }

    /// Reconcile credentials changed by the widget while the app was closed.
    ///
    /// Refresh-token rotation invalidates the old refresh token. Previously the
    /// app always copied its Keychain pair over the App Group at launch, which
    /// could overwrite a newer pair the widget had just rotated. The next token
    /// refresh then failed and incorrectly signed the person out.
    static func syncToSharedStore() {
        let localAccess = Keychain.get("access")
        let localRefresh = Keychain.get("refresh")
        let localUpdatedAt = Keychain.get(updatedAtKey).flatMap { TimeInterval($0) }
            .map(Date.init(timeIntervalSince1970:))

        guard let shared = SharedTokenStore.tokenPair else {
            if let localAccess, let localRefresh {
                let timestamp = localUpdatedAt ?? Date()
                Keychain.set(String(timestamp.timeIntervalSince1970), for: updatedAtKey)
                SharedTokenStore.setTokens(accessToken: localAccess, refreshToken: localRefresh, updatedAt: timestamp)
            }
            return
        }

        let localIsComplete = localAccess?.isEmpty == false && localRefresh?.isEmpty == false
        let sharedIsNewer = (shared.updatedAt ?? .distantPast) > (localUpdatedAt ?? .distantPast)
        let sharedHasLaterExpiry = jwtExpiry(shared.accessToken) > jwtExpiry(localAccess)

        if !localIsComplete || sharedIsNewer || (localUpdatedAt == nil && sharedHasLaterExpiry) {
            // Do not write this pair back through `SharedTokenStore`: it is
            // already the authoritative widget-issued pair, and keeping its
            // timestamp makes repeated launches deterministic.
            Keychain.set(shared.accessToken, for: "access")
            Keychain.set(shared.refreshToken, for: "refresh")
            let timestamp = shared.updatedAt ?? Date()
            Keychain.set(String(timestamp.timeIntervalSince1970), for: updatedAtKey)
            return
        }

        if let localAccess, let localRefresh {
            let timestamp = localUpdatedAt ?? Date()
            Keychain.set(String(timestamp.timeIntervalSince1970), for: updatedAtKey)
            SharedTokenStore.setTokens(accessToken: localAccess, refreshToken: localRefresh, updatedAt: timestamp)
        }
    }

    /// If a competing app/widget request has already rotated the token pair,
    /// use it instead of treating our old refresh token's 401 as a sign-out.
    @discardableResult
    static func adoptSharedTokensIfNewer() -> Bool {
        let previousAccess = Keychain.get("access")
        let previousRefresh = Keychain.get("refresh")
        syncToSharedStore()
        return previousAccess != Keychain.get("access") || previousRefresh != Keychain.get("refresh")
    }

    /// The expiry is used only to migrate installations created before the
    /// timestamp existed; server validation remains the source of truth.
    private static func jwtExpiry(_ token: String?) -> Date {
        guard let token else { return .distantPast }
        let segments = token.split(separator: ".")
        guard segments.count > 1 else { return .distantPast }
        let payloadSegment = String(segments[1])
        let padding = String(repeating: "=", count: (4 - payloadSegment.count % 4) % 4)
        let base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/") + padding
        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else { return .distantPast }
        return Date(timeIntervalSince1970: exp)
    }
}
