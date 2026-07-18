import Foundation

struct DrawRound: Codable {
    let roundId: String
    let prompt: String
    let mySubmitted: Bool
    let partnerSubmitted: Bool
    let revealed: Bool          // both submitted → drawings shown
    let myImagePath: String?
    let partnerImagePath: String?
}
