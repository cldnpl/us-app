import Foundation

struct SnapRound: Codable {
    let roundId: String
    let clue: String
    let mySubmitted: Bool
    let partnerSubmitted: Bool
    let revealed: Bool
    let myImagePath: String?
    let partnerImagePath: String?
    let outcome: String?   // "me" | "partner" | "tie", when revealed
    let reason: String?
}
