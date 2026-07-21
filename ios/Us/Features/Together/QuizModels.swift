import SwiftUI
import UIKit

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

/// The row of capsule step indicators shared by every multi-step play flow
/// (quiz, know-me, debate): current step is a wide capsule, already-answered
/// steps are tinted, the rest are grey.
struct StepDots: View {
    let total: Int
    let index: Int
    let accent: Color
    /// Whether step `i` already has an answer saved.
    var isDone: (Int) -> Bool = { _ in false }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { i in
                Capsule()
                    .fill(i == index ? accent : (isDone(i) ? accent.opacity(0.4) : Color.secondary.opacity(0.2)))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
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
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

/// Maps a catalog colorKey to the soft two-tone card gradient.
///
/// These cards carry `Theme.ink` text, which is near-black on light and
/// off-white on dark — so the cards themselves have to flip with it. Each hue
/// keeps its identity in both schemes: a pale wash on light, a deep saturated
/// version of the same hue on dark.
enum QuizPalette {
    static func colors(_ key: String) -> [Color] {
        switch key {
        case "purple": return [d(0.83, 0.78, 0.98, 0.24, 0.19, 0.38), d(0.90, 0.86, 1.0, 0.17, 0.14, 0.28)]
        case "pink":   return [d(1.0, 0.80, 0.88, 0.38, 0.18, 0.28), d(1.0, 0.89, 0.93, 0.28, 0.13, 0.21)]
        case "red":    return [d(1.0, 0.78, 0.78, 0.38, 0.17, 0.17), d(1.0, 0.87, 0.86, 0.28, 0.12, 0.12)]
        case "amber":  return [d(1.0, 0.88, 0.70, 0.36, 0.25, 0.10), d(1.0, 0.93, 0.80, 0.27, 0.19, 0.08)]
        case "green":  return [d(0.80, 0.93, 0.83, 0.15, 0.32, 0.21), d(0.89, 0.96, 0.90, 0.11, 0.24, 0.16)]
        case "blue":   return [d(0.80, 0.89, 1.0, 0.15, 0.26, 0.42), d(0.89, 0.94, 1.0, 0.11, 0.20, 0.32)]
        default:       return [d(1.0, 0.85, 0.88, 0.34, 0.20, 0.24), d(1.0, 0.91, 0.85, 0.26, 0.16, 0.19)]
        }
    }

    static func gradient(_ key: String) -> LinearGradient {
        LinearGradient(colors: colors(key), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A stronger tint of the same hue for accents (progress bar, badge text).
    /// Lifted in dark mode so it still separates from the deep card behind it.
    static func accent(_ key: String) -> Color {
        switch key {
        case "purple": return d(0.55, 0.40, 0.90, 0.72, 0.62, 1.0)
        case "pink":   return d(0.93, 0.35, 0.60, 1.0, 0.55, 0.76)
        case "red":    return d(0.90, 0.30, 0.30, 1.0, 0.52, 0.52)
        case "amber":  return d(0.90, 0.60, 0.15, 1.0, 0.76, 0.35)
        case "green":  return d(0.20, 0.65, 0.40, 0.42, 0.85, 0.60)
        case "blue":   return d(0.25, 0.50, 0.90, 0.50, 0.72, 1.0)
        default:       return Theme.coral
        }
    }

    /// A colour with a light-mode and a dark-mode value.
    private static func d(_ lr: Double, _ lg: Double, _ lb: Double,
                          _ dr: Double, _ dg: Double, _ db: Double) -> Color {
        Color(dynamic: UIColor(red: lr, green: lg, blue: lb, alpha: 1),
              dark: UIColor(red: dr, green: dg, blue: db, alpha: 1))
    }
}
