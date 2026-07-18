import Foundation

extension APIClient {
    // MARK: Snap Hunt

    func getSnap() async throws -> SnapRound {
        try await send("/v1/games/snap")
    }

    func submitSnap(_ jpeg: Data) async throws -> SnapRound {
        let data = try await uploadImage("/v1/games/snap/submit", imageData: jpeg,
                                         filename: "snap.jpg", caption: nil)
        return try decoder.decode(SnapRound.self, from: data)
    }

    func newSnap() async throws -> SnapRound {
        try await send("/v1/games/snap/new", method: "POST")
    }
}
