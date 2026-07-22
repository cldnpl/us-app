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

    /// Persist how this user refers to their partner (she | he | they).
    @discardableResult
    func updatePartnerPronoun(_ pronoun: String) async throws -> User {
        try await send("/v1/me", method: "PATCH", body: ["partnerPronoun": pronoun])
    }

    /// Persist the account-level cycle settings so they survive a reinstall.
    @discardableResult
    func updateCycleSettings(hasCycle: Bool? = nil, shareLevel: String? = nil) async throws -> User {
        struct Body: Encodable { let hasCycle: Bool?; let cycleShareLevel: String? }
        return try await send("/v1/me", method: "PATCH",
                              body: Body(hasCycle: hasCycle, cycleShareLevel: shareLevel))
    }

    // MARK: - Changing the account email

    /// Starts an email change: the server mails a one-time code to `newEmail`.
    /// Nothing changes on the account until `confirmEmailChange` succeeds.
    func requestEmailChange(newEmail: String) async throws -> EmailChangeRequestResponse {
        try await send("/v1/me/email/request", method: "POST", body: ["newEmail": newEmail])
    }

    /// Completes an email change with the code from the message.
    func confirmEmailChange(code: String) async throws -> User {
        try await send("/v1/me/email/confirm", method: "POST", body: ["code": code])
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

    @discardableResult
    func updateMilestone(id: String, title: String, date: String) async throws -> Milestone {
        try await send("/v1/milestones/\(id)", method: "PATCH", body: ["title": title, "date": date])
    }

    func deleteMilestone(id: String) async throws {
        try await sendVoid("/v1/milestones/\(id)", method: "DELETE")
    }

    // MARK: - Journal

    func listJournal() async throws -> [JournalEntry] {
        let list: JournalList = try await send("/v1/journal")
        return list.entries
    }

    @discardableResult
    func createJournalEntry(date: String, body: String) async throws -> JournalEntry {
        try await send("/v1/journal", method: "POST", body: ["date": date, "body": body])
    }

    @discardableResult
    func updateJournalEntry(id: String, body: String) async throws -> JournalEntry {
        try await send("/v1/journal/\(id)", method: "PUT", body: ["body": body])
    }

    @discardableResult
    func uploadJournalPhoto(entryId: String, _ jpeg: Data) async throws -> MediaItem {
        let data = try await uploadImage("/v1/journal/\(entryId)/photos", imageData: jpeg, filename: "photo.jpg", caption: nil)
        return try decoder.decode(MediaItem.self, from: data)
    }

    func deleteJournalEntry(id: String) async throws {
        try await sendVoid("/v1/journal/\(id)", method: "DELETE")
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

    // MARK: - Cycle sharing

    /// Upload the caller's opt-in cycle summary. `note` carries the day's
    /// thoughts when sharing at the "cycle + thoughts" level (nil otherwise).
    func putCycle(phase: String, cycleDay: Int?, periodInDays: Int?, note: String?) async throws {
        struct Body: Encodable { let phase: String; let cycleDay: Int?; let periodInDays: Int?; let note: String? }
        try await sendVoid("/v1/cycle", method: "PUT",
                           body: Body(phase: phase, cycleDay: cycleDay, periodInDays: periodInDays, note: note))
    }

    func partnerCycle() async throws -> PartnerCycle {
        try await send("/v1/cycle")
    }

    func stopSharingCycle() async throws {
        try await sendVoid("/v1/cycle", method: "DELETE")
    }

    // MARK: - Pregnancy sharing

    func putPregnancy(dueDate: Date) async throws {
        let iso = dueDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        struct Body: Encodable { let dueDate: String }
        try await sendVoid("/v1/pregnancy", method: "PUT", body: Body(dueDate: iso))
    }

    func partnerPregnancy() async throws -> PartnerPregnancy {
        try await send("/v1/pregnancy")
    }

    func stopSharingPregnancy() async throws {
        try await sendVoid("/v1/pregnancy", method: "DELETE")
    }
}
