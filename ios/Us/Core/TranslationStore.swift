import Foundation

/// A plain, lock-protected snapshot of the current language's UI strings.
///
/// `LocalizedBundle.localizedString(forKey:...)` (see `LanguageManager.swift`)
/// can be called from background rendering/layout threads, not just the main
/// actor — so it must read from here, never from `TranslationStore.strings`
/// directly (`TranslationStore` is `@MainActor`).
private final class TranslationSnapshot: @unchecked Sendable {
    static let shared = TranslationSnapshot()

    private let lock = NSLock()
    private var strings: [String: String] = [:]

    func update(_ newStrings: [String: String]) {
        lock.lock(); defer { lock.unlock() }
        strings = newStrings
    }

    /// Per-key fallback: a language missing one string shouldn't take the
    /// whole bundle down with it — the caller falls through to bundled English.
    func string(forKey key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return strings[key]
    }
}

private struct TranslationsResponse: Decodable {
    let lang: String
    let strings: [String: String]
}

/// Fetches UI string translations from the backend, with a disk cache for
/// offline/repeat launches and a loading flag the language picker uses to
/// block the UI while a switch is in flight.
@MainActor
final class TranslationStore: ObservableObject {
    static let shared = TranslationStore()

    @Published private(set) var strings: [String: String] = [:]
    @Published private(set) var isLoading = false

    private init() {}

    /// Loads the disk cache for `lang` synchronously if present, so a relaunch
    /// on a non-English language shows translated text immediately rather than
    /// flashing English while the network fetch is in flight. Does not fetch.
    func loadCachedIfAvailable(for lang: String) {
        guard let cached = Self.readCache(for: lang) else { return }
        strings = cached
        TranslationSnapshot.shared.update(cached)
    }

    /// Fetches `/v1/translations/{lang}`, updates the published/snapshot
    /// state, and writes the disk cache. On network failure, falls back to
    /// whatever's on disk for `lang` — the snapshot is left as whatever was
    /// there before (bundled English, if nothing else) if there's no cache.
    func load(for lang: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: TranslationsResponse = try await APIClient.shared.send(
                "translations/\(lang)", method: "GET", authorized: false)
            strings = response.strings
            TranslationSnapshot.shared.update(response.strings)
            Self.writeCache(response.strings, for: lang)
        } catch {
            if let cached = Self.readCache(for: lang) {
                strings = cached
                TranslationSnapshot.shared.update(cached)
            } else {
                // Do not leave the previous language's snapshot active after
                // a failed switch. LocalizedBundle will then fall through to
                // the bundled English catalog.
                strings = [:]
                TranslationSnapshot.shared.update([:])
            }
        }
    }

    // MARK: - Disk cache

    private static func cacheURL(for lang: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return dir.appendingPathComponent("translations_\(lang).json")
    }

    private static func readCache(for lang: String) -> [String: String]? {
        guard let url = cacheURL(for: lang),
              let data = try? Data(contentsOf: url),
              let strings = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return strings
    }

    private static func writeCache(_ strings: [String: String], for lang: String) {
        guard let url = cacheURL(for: lang),
              let data = try? JSONEncoder().encode(strings)
        else { return }
        try? data.write(to: url, options: .atomic)
    }
}

extension Bundle {
    /// Looks up a translated string in the network-sourced snapshot first,
    /// falling back to nil (never the bundle) — callers layer their own next
    /// fallback rung on top. Safe to call from any thread.
    static func translatedString(forKey key: String) -> String? {
        TranslationSnapshot.shared.string(forKey: key)
    }
}
