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
}
