import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let displayName: String
    let avatarPath: String?
    let birthday: Date?
    let partnerPronoun: String?
    let createdAt: Date

    /// Whether the address was confirmed with a code we emailed to it.
    /// Optional so sessions cached by older builds still decode.
    let emailVerified: Bool?
    /// Account-level cycle settings, kept server-side so they survive a
    /// reinstall. `hasCycle` is nil when the question was never answered.
    let hasCycle: Bool?
    let cycleShareLevel: String?

    init(id: String, email: String?, displayName: String, avatarPath: String?,
         birthday: Date?, partnerPronoun: String?, createdAt: Date,
         emailVerified: Bool? = nil, hasCycle: Bool? = nil, cycleShareLevel: String? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarPath = avatarPath
        self.birthday = birthday
        self.partnerPronoun = partnerPronoun
        self.createdAt = createdAt
        self.emailVerified = emailVerified
        self.hasCycle = hasCycle
        self.cycleShareLevel = cycleShareLevel
    }
}

/// Server acknowledgement that an email-change code was issued. `devCode` is
/// only ever populated by a dev server with no mail provider configured.
struct EmailChangeRequestResponse: Codable {
    let sentTo: String
    let expiresAt: Date
    let devCode: String?
}

struct Couple: Codable, Equatable {
    let id: String
    let startDate: Date?
    let status: String
    let createdAt: Date
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
}

struct CoupleResponse: Codable {
    let paired: Bool
    let couple: Couple?
    let partner: User?
}

struct PairingCode: Codable {
    let code: String
    let expiresAt: Date
}

struct MissYouEvent: Codable, Identifiable {
    let id: String
    let senderId: String
    let kind: String
    let createdAt: Date
}

struct MissYouList: Codable {
    let events: [MissYouEvent]
}

struct MediaItem: Codable, Identifiable {
    let id: String
    let kind: String
    let caption: String?
    let uploaderId: String
    let fileUrl: String
    let thumbUrl: String
    let createdAt: Date
}

struct MediaList: Codable {
    let media: [MediaItem]
    let count: Int
    let storageUsed: Int64
}

struct Milestone: Codable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let kind: String
}

struct MilestoneList: Codable {
    let milestones: [Milestone]
}

/// One partner's diary entry for a day: free text and/or photos. Both partners'
/// entries for the same date are grouped under a shared day card on the client.
struct JournalEntry: Codable, Identifiable {
    let id: String
    let authorId: String
    let date: Date
    let body: String
    let photos: [MediaItem]
    let createdAt: Date
    let updatedAt: Date
}

struct JournalList: Codable {
    let entries: [JournalEntry]
}

struct Reunion: Codable, Identifiable {
    let id: String
    let title: String
    let targetDate: Date
}

struct ReunionList: Codable {
    let reunions: [Reunion]
}

struct PartnerLocation: Codable {
    let sharing: Bool
    let lat: Double?
    let lng: Double?
    let mode: String?
    let partnerName: String?
    let updatedAt: Date?
}

/// The partner's opt-in shared cycle summary, or `{sharing:false}`. Coarse by
/// design: a phase, and optionally a day count — never raw symptoms.
struct PartnerCycle: Codable {
    let sharing: Bool
    let phase: String?
    let cycleDay: Int?
    let periodInDays: Int?
    let note: String?
    let partnerName: String?
    let updatedAt: Date?
}

/// The partner's opt-in shared due date, or `{sharing:false}`. Week, trimester,
/// and countdown are derived on the client.
struct PartnerPregnancy: Codable {
    let sharing: Bool
    let dueDate: Date?
    let partnerName: String?
    let updatedAt: Date?
}

/// Error payload returned by the API ({"error": "...", "code": "..."}).
struct APIErrorResponse: Codable, Error {
    let error: String
    let code: String?
}
