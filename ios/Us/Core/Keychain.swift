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
    static var accessToken: String? {
        get { Keychain.get("access") }
        set { Keychain.set(newValue, for: "access"); SharedTokenStore.accessToken = newValue }
    }
    static var refreshToken: String? {
        get { Keychain.get("refresh") }
        set { Keychain.set(newValue, for: "refresh"); SharedTokenStore.refreshToken = newValue }
    }
    static func clear() {
        Keychain.delete("access")
        Keychain.delete("refresh")
        SharedTokenStore.clear()
    }

    /// Mirror the Keychain tokens into the App Group. Call on launch so existing
    /// installs (whose tokens predate the shared store) become widget-usable.
    static func syncToSharedStore() {
        SharedTokenStore.accessToken = Keychain.get("access")
        SharedTokenStore.refreshToken = Keychain.get("refresh")
    }
}
