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
    let bothDone: Bool
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
    let motion: String
    let mySide: String           // "for" | "against"
    let myArgument: String?
    let partnerArgument: String? // revealed once both have argued
    let judged: Bool
    let myScore: Int?
    let partnerScore: Int?
    let roundWinner: String?     // "me" | "partner" | "tie"
    let verdict: String?
}
