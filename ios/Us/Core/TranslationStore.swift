import Foundation
import SwiftUI

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
                "/v1/translations/\(lang)", method: "GET", authorized: false)
            strings = response.strings
            TranslationSnapshot.shared.update(response.strings)
            Self.writeCache(response.strings, for: lang)
        } catch {
            if let cached = Self.readCache(for: lang) {
                strings = cached
                TranslationSnapshot.shared.update(cached)
            } else if let fallback = BundledTranslationFallback.strings(for: lang) {
                // The public translation endpoint may lag behind an iOS release.
                // Keep the primary navigation and settings visibly translated
                // instead of silently reverting the whole app to English.
                strings = fallback
                TranslationSnapshot.shared.update(fallback)
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

/// A small offline catalog for the persistent app chrome. The complete catalog
/// still arrives from the API when it is available, but these keys make the
/// selected language immediately apparent during a backend rollout or offline.
private enum BundledTranslationFallback {
    static func strings(for language: String) -> [String: String]? { values[language] }

    private static let values: [String: [String: String]] = [
        "ar": ["Home": "الرئيسية", "Games": "الألعاب", "Journal": "المذكرات", "Settings": "الإعدادات", "Language": "اللغة", "You": "أنت", "Partner": "الشريك"],
        "bn": ["Home": "হোম", "Games": "গেম", "Journal": "ডায়েরি", "Settings": "সেটিংস", "Language": "ভাষা", "You": "আপনি", "Partner": "সঙ্গী"],
        "da": ["Home": "Hjem", "Games": "Spil", "Journal": "Dagbog", "Settings": "Indstillinger", "Language": "Sprog", "You": "Dig", "Partner": "Partner"],
        "de": ["Home": "Start", "Games": "Spiele", "Journal": "Tagebuch", "Settings": "Einstellungen", "Language": "Sprache", "You": "Du", "Partner": "Partner"],
        "es": ["Home": "Inicio", "Games": "Juegos", "Journal": "Diario", "Settings": "Ajustes", "Language": "Idioma", "You": "Tú", "Partner": "Pareja"],
        "fa": ["Home": "خانه", "Games": "بازی‌ها", "Journal": "دفترچه", "Settings": "تنظیمات", "Language": "زبان", "You": "شما", "Partner": "همراه"],
        "fil": ["Home": "Home", "Games": "Mga Laro", "Journal": "Talaarawan", "Settings": "Mga Setting", "Language": "Wika", "You": "Ikaw", "Partner": "Partner"],
        "fr": ["Home": "Accueil", "Games": "Jeux", "Journal": "Journal", "Settings": "Réglages", "Language": "Langue", "You": "Vous", "Partner": "Partenaire"],
        "hi": ["Home": "होम", "Games": "गेम", "Journal": "डायरी", "Settings": "सेटिंग्स", "Language": "भाषा", "You": "आप", "Partner": "साथी"],
        "id": ["Home": "Beranda", "Games": "Permainan", "Journal": "Jurnal", "Settings": "Pengaturan", "Language": "Bahasa", "You": "Kamu", "Partner": "Pasangan"],
        "it": ["Home": "Home", "Games": "Giochi", "Journal": "Diario", "Settings": "Impostazioni", "Language": "Lingua", "You": "Tu", "Partner": "Partner"],
        "ja": ["Home": "ホーム", "Games": "ゲーム", "Journal": "日記", "Settings": "設定", "Language": "言語", "You": "あなた", "Partner": "パートナー"],
        "ko": ["Home": "홈", "Games": "게임", "Journal": "일기", "Settings": "설정", "Language": "언어", "You": "나", "Partner": "파트너"],
        "nl": ["Home": "Start", "Games": "Spellen", "Journal": "Dagboek", "Settings": "Instellingen", "Language": "Taal", "You": "Jij", "Partner": "Partner"],
        "pl": ["Home": "Główna", "Games": "Gry", "Journal": "Dziennik", "Settings": "Ustawienia", "Language": "Język", "You": "Ty", "Partner": "Partner"],
        "pt-BR": ["Home": "Início", "Games": "Jogos", "Journal": "Diário", "Settings": "Ajustes", "Language": "Idioma", "You": "Você", "Partner": "Parceiro"],
        "ru": ["Home": "Главная", "Games": "Игры", "Journal": "Дневник", "Settings": "Настройки", "Language": "Язык", "You": "Вы", "Partner": "Партнёр"],
        "sw": ["Home": "Mwanzo", "Games": "Michezo", "Journal": "Shajara", "Settings": "Mipangilio", "Language": "Lugha", "You": "Wewe", "Partner": "Mwenzi"],
        "th": ["Home": "หน้าแรก", "Games": "เกม", "Journal": "ไดอารี่", "Settings": "ตั้งค่า", "Language": "ภาษา", "You": "คุณ", "Partner": "คู่ของคุณ"],
        "tr": ["Home": "Ana Sayfa", "Games": "Oyunlar", "Journal": "Günlük", "Settings": "Ayarlar", "Language": "Dil", "You": "Sen", "Partner": "Partner"],
        "uk": ["Home": "Головна", "Games": "Ігри", "Journal": "Щоденник", "Settings": "Налаштування", "Language": "Мова", "You": "Ви", "Partner": "Партнер"],
        "ur": ["Home": "ہوم", "Games": "گیمز", "Journal": "ڈائری", "Settings": "ترتیبات", "Language": "زبان", "You": "آپ", "Partner": "ساتھی"],
        "uz": ["Home": "Bosh sahifa", "Games": "O‘yinlar", "Journal": "Kundalik", "Settings": "Sozlamalar", "Language": "Til", "You": "Siz", "Partner": "Sherik"],
        "vi": ["Home": "Trang chủ", "Games": "Trò chơi", "Journal": "Nhật ký", "Settings": "Cài đặt", "Language": "Ngôn ngữ", "You": "Bạn", "Partner": "Người ấy"],
        "zh-Hans": ["Home": "主页", "Games": "游戏", "Journal": "日记", "Settings": "设置", "Language": "语言", "You": "你", "Partner": "伴侣"]
    ]
}

extension Bundle {
    /// Looks up a translated string in the network-sourced snapshot first,
    /// falling back to nil (never the bundle) — callers layer their own next
    /// fallback rung on top. Safe to call from any thread.
    static func translatedString(forKey key: String) -> String? {
        TranslationSnapshot.shared.string(forKey: key)
    }
}

extension String {
    /// Explicit translation lookup, resolved right now against the current
    /// language snapshot. Prefer over `Text("literal")` when you can't be sure
    /// SwiftUI will route the literal through `LocalizedBundle` (Text/Label
    /// with an xcstrings catalog on iOS 17+ sometimes bypasses the swizzled
    /// `Bundle.main`, leaving the string in the source language).
    var loc: String {
        Bundle.translatedString(forKey: self) ?? self
    }

    /// Same as `loc` but with printf-style substitutions applied on top of the
    /// translated template. Use with format keys like `"%@ days together 💜"`.
    func loc(_ args: CVarArg...) -> String {
        let template = Bundle.translatedString(forKey: self) ?? self
        return withVaList(args) { NSString(format: template, arguments: $0) as String }
    }
}

extension Text {
    /// `Text` initializer that resolves against the current-language snapshot
    /// at render time. Guaranteed to translate as long as the snapshot has the
    /// key, regardless of SwiftUI's bundle-lookup behavior.
    init(loc key: String) {
        self.init(verbatim: key.loc)
    }
}

extension Label where Title == Text, Icon == Image {
    init(loc key: String, systemImage name: String) {
        self.init { Text(loc: key) } icon: { Image(systemName: name) }
    }
}

extension Button where Label == Text {
    init(loc key: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.init(role: role, action: action) { Text(loc: key) }
    }
}
