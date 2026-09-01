import Foundation

extension APIClient {
    // MARK: Couples Debate

    func getDebatePacks() async throws -> [DebatePackSummary] {
        let resp: DebatePacksResponse = try await send("/v1/games/debate/packs")
        return resp.packs
    }

    func getDebatePack(_ id: String) async throws -> DebatePackDetail {
        try await send("/v1/games/debate/packs/\(id)")
    }

    func argueDebate(_ packId: String, roundId: String, argument: String) async throws {
        try await sendVoid("/v1/games/debate/packs/\(packId)/argue", method: "POST",
                           body: ["roundId": roundId, "argument": argument])
    }

    /// Tells the server we've opened the results screen for this pack. Once
    /// both partners have called this on the same round, the pack rotates on
    /// the server — the next fetch returns brand-new motions.
    func markDebatePackSeen(_ packId: String) async throws {
        try await sendVoid("/v1/games/debate/packs/\(packId)/seen", method: "POST")
    }
}
