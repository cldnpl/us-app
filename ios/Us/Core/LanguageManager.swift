import Foundation
import SwiftUI

/// Owns the app's display language.
///
/// iOS normally picks the language from the system settings. This lets someone
/// choose a different one *inside* Us. — useful when the phone is in a language
/// they don't share with their partner, or when the phone language isn't one we
/// support but a second language they speak is.
///
/// The choice takes effect immediately: `Bundle.setLanguage` redirects string
/// lookups, and the root view is rebuilt with a matching locale and layout
/// direction. Nothing needs a restart.
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let storageKey = "appLanguage"

    @Published private(set) var current: AppLanguage

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        current = saved.flatMap(AppLanguage.named) ?? AppLanguage.deviceDefault
        Bundle.setLanguage(current.code)
    }

    func select(_ language: AppLanguage) {
        guard language != current else { return }
        UserDefaults.standard.set(language.code, forKey: Self.storageKey)
        // Also tell the system, so anything we don't route through our own
        // bundle override (system dialogs, share sheets) follows along on the
        // next launch.
        UserDefaults.standard.set([language.code], forKey: "AppleLanguages")
        Bundle.setLanguage(language.code)
        current = language
    }

    /// Locale handed to SwiftUI so dates, numbers and plurals match the choice.
    var locale: Locale { Locale(identifier: current.code) }

    var layoutDirection: LayoutDirection { current.isRTL ? .rightToLeft : .leftToRight }
}

// MARK: - Bundle override

/// A bundle whose string lookups are redirected to a specific `.lproj`.
///
/// Swapping the class of `Bundle.main` at runtime is what makes switching
/// language immediate rather than requiring a relaunch: every
/// `NSLocalizedString` / SwiftUI `Text("…")` lookup goes through here.
private final class LocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &Bundle.overrideBundleKey) as? String,
              let override = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return override.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var overrideBundleKey: UInt8 = 0

    /// Points `Bundle.main` at the given language's resources.
    ///
    /// Falls back silently when a language has no compiled `.lproj` yet — the
    /// app then serves the development language (English) for every string,
    /// which is exactly the behaviour we want while translations are still
    /// being filled in.
    static func setLanguage(_ code: String) {
        // Swap the class exactly once; after that only the associated path changes.
        if !(Bundle.main is LocalizedBundle) {
            object_setClass(Bundle.main, LocalizedBundle.self)
        }
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
            // "pt-BR" ships as "pt-BR.lproj", but be forgiving about region
            // suffixes so a missing regional variant still finds its base.
            ?? code.split(separator: "-").first.flatMap {
                Bundle.main.path(forResource: String($0), ofType: "lproj")
            }
        objc_setAssociatedObject(Bundle.main, &overrideBundleKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
