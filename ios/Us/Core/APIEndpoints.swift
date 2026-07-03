import Foundation

/// High-level API methods mapping to the Us backend endpoints.
extension APIClient {
    func register(email: String, password: String, displayName: String) async throws -> AuthResponse {
        try await send("/v1/auth/register", method: "POST",
                       body: ["email": email, "password": password, "displayName": displayName],
                       authorized: false)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await send("/v1/auth/login", method: "POST",
                       body: ["email": email, "password": password], authorized: false)
    }

    func appleSignIn(identityToken: String, displayName: String) async throws -> AuthResponse {
        try await send("/v1/auth/apple", method: "POST",
                       body: ["identityToken": identityToken, "displayName": displayName], authorized: false)
    }

    func logout() async throws {
        guard let rt = TokenStore.refreshToken else { return }
        try await sendVoid("/v1/auth/logout", method: "POST", body: ["refreshToken": rt], authorized: false)
    }

    func me() async throws -> User {
        try await send("/v1/me")
    }

    func updateProfile(displayName: String) async throws -> User {
        try await send("/v1/me", method: "PATCH", body: ["displayName": displayName])
    }

    func getCouple() async throws -> CoupleResponse {
        try await send("/v1/couple")
    }

    func createPairingCode() async throws -> PairingCode {
        try await send("/v1/pairing/code", method: "POST")
    }

    func redeemPairing(code: String) async throws -> CoupleResponse {
        try await send("/v1/pairing/redeem", method: "POST", body: ["code": code])
    }

    func setStartDate(_ isoDate: String) async throws -> Couple {
        try await send("/v1/couple", method: "PATCH", body: ["startDate": isoDate])
    }

    func unpair() async throws {
        try await sendVoid("/v1/couple", method: "DELETE")
    }

    func sendMissYou() async throws -> MissYouEvent {
        try await send("/v1/miss-you", method: "POST")
    }

    func listMissYou() async throws -> MissYouList {
        try await send("/v1/miss-you")
    }

    func registerDevice(apnsToken: String, environment: String) async throws {
        try await sendVoid("/v1/devices", method: "POST",
                           body: ["apnsToken": apnsToken, "environment": environment])
    }

    // MARK: - Gallery

    func listMedia() async throws -> MediaList {
        try await send("/v1/media")
    }

    func uploadPhoto(_ jpeg: Data, caption: String?) async throws -> MediaItem {
        let data = try await uploadImage("/v1/media", imageData: jpeg, filename: "photo.jpg", caption: caption)
        return try decoder.decode(MediaItem.self, from: data)
    }

    func deletePhoto(id: String) async throws {
        try await sendVoid("/v1/media/\(id)", method: "DELETE")
    }

    /// Loads image bytes for a relative media path (thumb or full).
    func imageData(relativePath: String) async throws -> Data {
        try await fetchData(relativePath)
    }

    // MARK: - Moments

    func listMilestones() async throws -> [Milestone] {
        let list: MilestoneList = try await send("/v1/milestones")
        return list.milestones
    }

    func createMilestone(title: String, date: String, kind: String) async throws -> Milestone {
        try await send("/v1/milestones", method: "POST",
                       body: ["title": title, "date": date, "kind": kind])
    }

    func deleteMilestone(id: String) async throws {
        try await sendVoid("/v1/milestones/\(id)", method: "DELETE")
    }

    func listReunions() async throws -> [Reunion] {
        let list: ReunionList = try await send("/v1/reunions")
        return list.reunions
    }

    func createReunion(title: String, targetDate: String) async throws -> Reunion {
        try await send("/v1/reunions", method: "POST",
                       body: ["title": title, "targetDate": targetDate])
    }

    func deleteReunion(id: String) async throws {
        try await sendVoid("/v1/reunions/\(id)", method: "DELETE")
    }

    // MARK: - Partner location

    func updateLocation(lat: Double, lng: Double, accuracy: Double?, mode: String) async throws {
        struct Body: Encodable { let lat: Double; let lng: Double; let accuracy: Double?; let mode: String }
        try await sendVoid("/v1/location", method: "PUT",
                           body: Body(lat: lat, lng: lng, accuracy: accuracy, mode: mode))
    }

    func stopSharingLocation() async throws {
        try await sendVoid("/v1/location", method: "PUT", body: ["mode": "off"])
    }

    func partnerLocation() async throws -> PartnerLocation {
        try await send("/v1/location")
    }
}
