import Foundation

/// A language Us. can be displayed in.
///
/// The list is chosen for world coverage rather than country count: one entry
/// per major language bloc (the Americas, Europe, the ex-Soviet states, MENA,
/// South and South-East Asia, East Asia, and the largest African linguae
/// francae), plus Uzbek because that's home.
///
/// `code` must match a localization folder in the app bundle (and the language
/// keys in `Localizable.xcstrings`), because that's what we hand to the bundle
/// when overriding the language.
struct AppLanguage: Identifiable, Hashable {
    let code: String
    /// The language's name *in that language* — someone looking for their own
    /// language recognises "Русский", not "Russian".
    let endonym: String
    /// The same name in English, shown underneath as a subtitle.
    let englishName: String
    /// Written right-to-left; the UI mirrors for these.
    let isRTL: Bool

    var id: String { code }

    init(_ code: String, _ endonym: String, _ englishName: String, rtl: Bool = false) {
        self.code = code
        self.endonym = endonym
        self.englishName = englishName
        self.isRTL = rtl
    }

    /// Every language the app offers, roughly ordered by number of speakers so
    /// the most likely picks are near the top.
    static let all: [AppLanguage] = [
        AppLanguage("en",      "English",            "English"),
        AppLanguage("zh-Hans", "简体中文",              "Chinese (Simplified)"),
        AppLanguage("es",      "Español",            "Spanish"),
        AppLanguage("hi",      "हिन्दी",                "Hindi"),
        AppLanguage("ar",      "العربية",              "Arabic", rtl: true),
        AppLanguage("pt-BR",   "Português",          "Portuguese (Brazil)"),
        AppLanguage("ru",      "Русский",            "Russian"),
        AppLanguage("bn",      "বাংলা",                "Bengali"),
        AppLanguage("ja",      "日本語",               "Japanese"),
        AppLanguage("de",      "Deutsch",            "German"),
        AppLanguage("fr",      "Français",           "French"),
        AppLanguage("ko",      "한국어",               "Korean"),
        AppLanguage("tr",      "Türkçe",             "Turkish"),
        AppLanguage("vi",      "Tiếng Việt",         "Vietnamese"),
        AppLanguage("it",      "Italiano",           "Italian"),
        AppLanguage("id",      "Bahasa Indonesia",   "Indonesian"),
        AppLanguage("ur",      "اردو",                "Urdu", rtl: true),
        AppLanguage("fa",      "فارسی",               "Persian", rtl: true),
        AppLanguage("pl",      "Polski",             "Polish"),
        AppLanguage("uk",      "Українська",         "Ukrainian"),
        AppLanguage("th",      "ไทย",                 "Thai"),
        AppLanguage("nl",      "Nederlands",         "Dutch"),
        AppLanguage("sw",      "Kiswahili",          "Swahili"),
        AppLanguage("fil",     "Filipino",           "Filipino"),
        AppLanguage("uz",      "Oʻzbekcha",          "Uzbek"),
    ]

    static func named(_ code: String) -> AppLanguage? {
        all.first { $0.code == code }
    }

    /// The best match for the language the phone itself is set to, so someone
    /// who has never opened this screen still gets their own language.
    static var deviceDefault: AppLanguage {
        for preferred in Locale.preferredLanguages {
            if let exact = all.first(where: { $0.code.caseInsensitiveCompare(preferred) == .orderedSame }) {
                return exact
            }
            // "pt-PT" → "pt-BR", "en-GB" → "en": match on the base language.
            let base = preferred.split(separator: "-").first.map(String.init) ?? preferred
            if let loose = all.first(where: { $0.code.split(separator: "-").first.map(String.init) == base }) {
                return loose
            }
        }
        return all[0]
    }
}
