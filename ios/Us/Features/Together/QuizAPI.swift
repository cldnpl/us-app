import Foundation

extension APIClient {
    func getQuizCategories() async throws -> [QuizCategorySummary] {
        let resp: QuizCategoriesResponse = try await send("/v1/quiz/categories")
        return resp.categories
    }

    func getQuizCategory(_ id: String) async throws -> QuizCategoryDetail {
        try await send("/v1/quiz/categories/\(id)")
    }

    func getQuiz(_ id: String) async throws -> QuizDetail {
        try await send("/v1/quiz/\(id)")
    }

    func answerQuiz(_ quizId: String, questionId: String, answer: String) async throws {
        try await sendVoid("/v1/quiz/\(quizId)/answer", method: "POST",
                           body: ["questionId": questionId, "answer": answer])
    }

    func getDailyQuiz() async throws -> QuizDaily {
        try await send("/v1/quiz/daily")
    }

    func answerDailyQuiz(_ answer: String) async throws {
        try await sendVoid("/v1/quiz/daily/answer", method: "POST", body: ["answer": answer])
    }

    // MARK: How Well Do You Know Me

    func getHwdykmPacks() async throws -> [HwdykmPackSummary] {
        let resp: HwdykmPacksResponse = try await send("/v1/games/hwdykm/packs")
        return resp.packs
    }

    func getHwdykmPack(_ id: String) async throws -> HwdykmPackDetail {
        try await send("/v1/games/hwdykm/packs/\(id)")
    }

    func answerHwdykm(_ packId: String, questionId: String, answer: String) async throws {
        try await sendVoid("/v1/games/hwdykm/packs/\(packId)/answer", method: "POST",
                           body: ["questionId": questionId, "answer": answer])
    }
}
