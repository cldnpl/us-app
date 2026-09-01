import Foundation

extension APIClient {
    // MARK: Snap Hunt

    func getSnap() async throws -> SnapRound {
        try await send("/v1/games/snap")
    }

    func submitSnap(_ jpeg: Data, roundID: String) async throws -> SnapRound {
        let data = try await uploadImage("/v1/games/snap/submit", imageData: jpeg,
                                         filename: "snap.jpg", caption: nil,
                                         queryItems: [URLQueryItem(name: "roundId", value: roundID)])
        return try decoder.decode(SnapRound.self, from: data)
    }

    /// `force` abandons an in-progress hunt even if the partner hasn't snapped
    /// yet. Without it the server returns 409 `snap_waiting`.
    func newSnap(force: Bool = false) async throws -> SnapRound {
        try await send("/v1/games/snap/new", method: "POST",
                       queryItems: force ? [URLQueryItem(name: "force", value: "1")] : [])
    }
}
