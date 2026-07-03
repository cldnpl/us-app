import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String?
    let displayName: String
    let avatarPath: String?
    let birthday: Date?
    let createdAt: Date
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

/// Error payload returned by the API ({"error": "...", "code": "..."}).
struct APIErrorResponse: Codable, Error {
    let error: String
    let code: String?
}
