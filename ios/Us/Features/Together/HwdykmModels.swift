import Foundation

struct HwdykmPacksResponse: Codable { let packs: [HwdykmPackSummary] }

struct HwdykmPackSummary: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let colorKey: String
    let tag: String
    let questionCount: Int
    let myDone: Bool
    /// Optional: sent only by a backend that reports the partner's half.
    var partnerDone: Bool? = nil
    let bothDone: Bool

    /// They finished this pack and I haven't — my move.
    var isMyTurn: Bool { !myDone && partnerDone == true }
}

struct HwdykmPackDetail: Codable {
    let id: String
    let title: String
    let icon: String
    let colorKey: String
    let tag: String
    let myDone: Bool
    let bothDone: Bool
    let score: Int
    let questions: [HwdykmQuestion]
}

struct HwdykmOption: Codable, Identifiable {
    let id: String
    let label: String
}

struct HwdykmQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let options: [HwdykmOption]
    let subjectIsMe: Bool      // true → I answer honestly; false → I guess my partner
    let myAnswer: String?      // option id
    let honestAnswer: String?  // option id, reveal only
    let guess: String?         // option id, reveal only
    let matched: Bool

    /// Look up the option matching a stored answer id, for display. Ids are
    /// stable across languages; labels are not, so never match on label.
    func option(for id: String?) -> HwdykmOption? {
        guard let id else { return nil }
        return options.first { $0.id == id }
    }
}
