import Foundation

struct TicTacToeState: Codable {
    let board: [String]   // 9 cells: "X", "O", or ""
    let x: String         // user id playing X
    let o: String         // user id playing O
    let winner: String    // "X", "O", "draw", or ""
}

struct Game: Codable {
    let id: String
    let gameType: String
    let state: TicTacToeState
    let turnUserId: String?
    let status: String    // "active" | "finished"
    let updatedAt: Date
}

struct DailyQuestion: Codable {
    let question: String
    let myAnswer: String?
    let partnerAnswer: String?
    let bothAnswered: Bool
}
