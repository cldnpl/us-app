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
    /// Older deployed API versions do not include this presentation hint yet.
    /// Decode those rounds too so a staged app release never blocks Snap Hunt.
    let startedByMe: Bool

    private enum CodingKeys: String, CodingKey {
        case roundId, clue, mySubmitted, partnerSubmitted, revealed
        case myImagePath, partnerImagePath, outcome, reason, startedByMe
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        roundId = try values.decode(String.self, forKey: .roundId)
        clue = try values.decode(String.self, forKey: .clue)
        mySubmitted = try values.decode(Bool.self, forKey: .mySubmitted)
        partnerSubmitted = try values.decode(Bool.self, forKey: .partnerSubmitted)
        revealed = try values.decode(Bool.self, forKey: .revealed)
        myImagePath = try values.decodeIfPresent(String.self, forKey: .myImagePath)
        partnerImagePath = try values.decodeIfPresent(String.self, forKey: .partnerImagePath)
        outcome = try values.decodeIfPresent(String.self, forKey: .outcome)
        reason = try values.decodeIfPresent(String.self, forKey: .reason)
        startedByMe = try values.decodeIfPresent(Bool.self, forKey: .startedByMe) ?? true
    }
}
