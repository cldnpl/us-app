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
    let bothDone: Bool
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

struct HwdykmQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let options: [String]
    let subjectIsMe: Bool      // true → I answer honestly; false → I guess my partner
    let myAnswer: String?
    let honestAnswer: String?  // reveal only
    let guess: String?         // reveal only
    let matched: Bool
}
