import Foundation

struct DebatePacksResponse: Codable { let packs: [DebatePackSummary] }

struct DebatePackSummary: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let colorKey: String
    let tag: String
    let roundCount: Int
    let myDone: Bool
    /// Optional: sent only by a backend that reports the partner's half.
    var partnerDone: Bool? = nil
    let bothDone: Bool

    /// They finished this pack and I haven't — my move.
    var isMyTurn: Bool { !myDone && partnerDone == true }
}

struct DebatePackDetail: Codable {
    let id: String
    let title: String
    let icon: String
    let colorKey: String
    let tag: String
    let myDone: Bool
    let bothDone: Bool
    let overallWinner: String?   // "me" | "partner" | "tie", when bothDone
    let myWins: Int
    let partnerWins: Int
    let rounds: [DebateRound]
}

struct DebateRound: Codable, Identifiable {
    let id: String
    /// The one statement both partners argue about. There are no assigned
    /// sides: you each make your own case for the same prompt, and the judge
    /// compares the two answers.
    let motion: String
    let myArgument: String?
    let partnerArgument: String? // revealed once both have argued
    let judged: Bool
    let myScore: Int?
    let partnerScore: Int?
    let roundWinner: String?     // "me" | "partner" | "tie"
    let verdict: String?
}
