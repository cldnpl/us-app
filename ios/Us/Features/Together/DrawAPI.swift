import Foundation

extension APIClient {
    // MARK: Draw Together

    func getDraw() async throws -> DrawRound {
        try await send("/v1/games/draw")
    }

    func submitDraw(_ jpeg: Data) async throws -> DrawRound {
        let data = try await uploadImage("/v1/games/draw/submit", imageData: jpeg,
                                         filename: "drawing.jpg", caption: nil)
        return try decoder.decode(DrawRound.self, from: data)
    }

    func newDrawRound() async throws -> DrawRound {
        try await send("/v1/games/draw/new", method: "POST")
    }
}
