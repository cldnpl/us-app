import SwiftUI

struct TogetherView: View {
    @State private var categories: [QuizCategorySummary] = []
    @State private var daily: QuizDaily?
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        dailySection
                        quizSection
                        gamesSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Games")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var dailySection: some View {
        Group {
            if let daily {
                NavigationLink {
                    DailyQuizView(onAnswered: { Task { await loadDaily() } })
                } label: {
                    DailyQuestionCard(daily: daily)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Quiz

    private var quizSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Quiz", subtitle: "Answer on your own, then compare")

            if loading && categories.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 30)
            } else if let errorMessage, categories.isEmpty {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    NavigationLink {
                        QuizCategoryDetailView(categoryId: category.id,
                                               categoryTitle: category.title,
                                               categoryIcon: category.icon)
                    } label: {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Games", subtitle: "Play together, at your own pace")

            ForEach(GameDef.all) { game in
                NavigationLink {
                    switch game.kind {
                    case .hwdykm: HwdykmPackListView()
                    case .debate: DebatePackListView()
                    case .draw: DrawTogetherView()
                    case .snap: SnapHuntView()
                    case .comingSoon: ComingSoonGameView(game: game)
                    }
                } label: {
                    GameCard(game: game)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold()).foregroundStyle(Theme.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func load() async {
        async let cats: () = loadCategories()
        async let day: () = loadDaily()
        _ = await (cats, day)
    }

    private func loadCategories() async {
        loading = true
        defer { loading = false }
        do {
            categories = try await APIClient.shared.getQuizCategories()
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func loadDaily() async {
        daily = try? await APIClient.shared.getDailyQuiz()
    }
}

/// The hero card at the top of Games: today's rotating question, category-coloured.
struct DailyQuestionCard: View {
    let daily: QuizDaily

    var body: some View {
        let accent = QuizPalette.accent(daily.colorKey)
        let answered = daily.question.myAnswer != nil
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("QUESTION OF THE DAY", systemImage: "sparkles")
                    .font(.caption.bold()).foregroundStyle(accent)
                Spacer()
                if answered {
                    Image(systemName: daily.question.bothAnswered ? "checkmark.circle.fill" : "clock.fill")
                        .foregroundStyle(accent)
                }
            }
            Text(daily.question.prompt)
                .font(.title3.bold())
                .foregroundStyle(Theme.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Image(systemName: daily.icon).font(.footnote.bold()).foregroundStyle(accent)
                Text(daily.categoryTitle).font(.subheadline.bold()).foregroundStyle(accent)
                Spacer()
                Text(answered ? (daily.question.bothAnswered ? "COMPARE" : "WAITING") : "ANSWER")
                    .font(.footnote.bold()).foregroundStyle(accent)
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(accent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient(daily.colorKey), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }
}

/// Topic card with emoji, title, and a colored progress bar (Couple Joy style).
struct CategoryCard: View {
    let category: QuizCategorySummary

    var body: some View {
        let accent = QuizPalette.accent(category.colorKey)
        HStack(spacing: 16) {
            QuizIconTile(systemName: category.icon, colorKey: category.colorKey)
            VStack(alignment: .leading, spacing: 8) {
                Text(category.title).font(.headline).foregroundStyle(Theme.ink)
                HStack(spacing: 10) {
                    ProgressBar(value: category.progress, accent: accent)
                    Text("\(Int((category.progress * 100).rounded()))%")
                        .font(.caption.bold()).foregroundStyle(accent)
                }
            }
            if category.progress >= 1 {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(accent)
            } else {
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient(category.colorKey), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

struct ProgressBar: View {
    let value: Double   // 0...1
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.5)).frame(height: 8)
                Capsule().fill(accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width, height: 8)
            }
        }
        .frame(height: 8)
    }
}
