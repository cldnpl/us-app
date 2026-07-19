import SwiftUI

// MARK: - Wire models (match the Go JSON, camelCase, no key conversion)

struct QuizCategoriesResponse: Codable {
    let categories: [QuizCategorySummary]
}

struct QuizCategorySummary: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String         // SF Symbol
    let colorKey: String
    let quizCount: Int
    let completedCount: Int
    let progress: Double   // 0...1, my completion
}

struct QuizCategoryDetail: Codable {
    let id: String
    let title: String
    let icon: String
    let colorKey: String
    let quizzes: [QuizSummary]
}

struct QuizSummary: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String         // SF Symbol
    let format: String       // QuizFormat raw
    let tag: String?         // "WEDDING", "18+", …
    let questionCount: Int
    let myDone: Bool
    let partnerDone: Bool
}

struct QuizDetail: Codable {
    let id: String
    let title: String
    let icon: String
    let format: String
    let tag: String?
    let questions: [QuizQuestion]
}

struct QuizDaily: Codable {
    let date: String
    let categoryId: String
    let categoryTitle: String
    let colorKey: String
    let icon: String          // SF Symbol
    let quizTitle: String
    let question: QuizQuestion
}

struct QuizQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let type: String            // "open" | "choice"
    let options: [QuizOption]?
    let myAnswer: String?
    let partnerAnswer: String?  // present only once I've answered this one
    let bothAnswered: Bool

    var isChoice: Bool { type == "choice" }
    /// True when this question's options carry photos (render as image cards).
    var hasPhotos: Bool { options?.contains { $0.image != nil } ?? false }

    /// Look up the option matching an answer label, to show its icon/photo in compare.
    func option(for label: String?) -> QuizOption? {
        guard let label else { return nil }
        return options?.first { $0.label == label }
    }
}

struct QuizOption: Codable, Identifiable {
    let label: String
    let icon: String?    // SF Symbol
    let image: String?   // photo keyword (loremflickr)

    var id: String { label }

    /// The backend resolves photo keywords to concrete, curated image URLs.
    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image)
    }
}

// MARK: - Presentation helpers

enum QuizFormat: String {
    case thisOrThat, deepConversation, whichDoYouPrefer

    /// Badge label shown on the quiz card, like Couple Joy.
    var badge: String {
        switch self {
        case .thisOrThat:       return "THIS OR THAT"
        case .deepConversation: return "DEEP CONVERSATION"
        case .whichDoYouPrefer: return "WHICH DO YOU PREFER?"
        }
    }
}

/// A rounded, tinted tile holding a category/quiz SF Symbol.
struct QuizIconTile: View {
    let systemName: String
    let colorKey: String
    var size: CGFloat = 54

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(QuizPalette.accent(colorKey))
            .frame(width: size, height: size)
            .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// Maps a catalog colorKey to the soft two-tone card gradient.
enum QuizPalette {
    static func colors(_ key: String) -> [Color] {
        switch key {
        case "purple": return [c(0.83, 0.78, 0.98), c(0.90, 0.86, 1.0)]
        case "pink":   return [c(1.0, 0.80, 0.88), c(1.0, 0.89, 0.93)]
        case "red":    return [c(1.0, 0.78, 0.78), c(1.0, 0.87, 0.86)]
        case "amber":  return [c(1.0, 0.88, 0.70), c(1.0, 0.93, 0.80)]
        case "green":  return [c(0.80, 0.93, 0.83), c(0.89, 0.96, 0.90)]
        case "blue":   return [c(0.80, 0.89, 1.0), c(0.89, 0.94, 1.0)]
        default:       return [Theme.blush.opacity(0.5), Theme.peach.opacity(0.4)]
        }
    }

    static func gradient(_ key: String) -> LinearGradient {
        LinearGradient(colors: colors(key), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A stronger tint of the same hue for accents (progress bar, badge text).
    static func accent(_ key: String) -> Color {
        switch key {
        case "purple": return c(0.55, 0.40, 0.90)
        case "pink":   return c(0.93, 0.35, 0.60)
        case "red":    return c(0.90, 0.30, 0.30)
        case "amber":  return c(0.90, 0.60, 0.15)
        case "green":  return c(0.20, 0.65, 0.40)
        case "blue":   return c(0.25, 0.50, 0.90)
        default:       return Theme.coral
        }
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }
}
