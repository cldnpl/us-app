import Foundation

extension APIClient {
    func getGame(_ type: String) async throws -> Game {
        try await send("/v1/games/\(type)")
    }

    func gameMove(_ type: String, index: Int) async throws -> Game {
        try await send("/v1/games/\(type)/move", method: "POST", body: ["index": index])
    }

    func newGame(_ type: String) async throws -> Game {
        try await send("/v1/games/\(type)/new", method: "POST")
    }

    func getDailyQuestion() async throws -> DailyQuestion {
        try await send("/v1/question")
    }

    func answerDailyQuestion(_ answer: String) async throws {
        try await sendVoid("/v1/question", method: "POST", body: ["answer": answer])
    }
}
