import Foundation

/// The grammatical pronoun the user picked for their partner during onboarding,
/// used to personalise copy ("thinking of her / him / them").
enum PartnerPronoun: String, CaseIterable, Identifiable {
    case she, he, they
    var id: String { rawValue }

    /// Object pronoun used in "thinking of ___".
    var object: String {
        switch self {
        case .she: return "her"
        case .he: return "him"
        case .they: return "them"
        }
    }

    /// Label shown in the picker.
    var label: String {
        switch self {
        case .she: return "She / her"
        case .he: return "He / him"
        case .they: return "They / them"
        }
    }
}

/// Small per-couple preferences shared with the widget via the App Group.
enum PartnerPrefs {
    private static let pronounKey = "partner_pronoun"
    private static let nameKey = "partner_name"

    static var pronoun: PartnerPronoun? {
        get {
            guard let raw = SharedConfig.defaults?.string(forKey: pronounKey) else { return nil }
            return PartnerPronoun(rawValue: raw)
        }
        set { SharedConfig.defaults?.set(newValue?.rawValue, forKey: pronounKey) }
    }

    static var partnerName: String? {
        get { SharedConfig.defaults?.string(forKey: nameKey) }
        set { SharedConfig.defaults?.set(newValue, forKey: nameKey) }
    }

    /// "thinking of her/him/them" — falls back to a neutral pronoun.
    static var thinkingOfObject: String { (pronoun ?? .they).object }
}
