import SwiftUI

struct TogetherView: View {
    @EnvironmentObject private var premium: PremiumStore
    @EnvironmentObject private var session: Session
    @State private var daily: QuizDaily?
    @State private var dailyError: String?
    @State private var lockedGame: GameDef?

    private var partnerName: String { session.partner?.displayName ?? "Your partner" }

    var body: some View {
        NavigationStack {
            // The gradient goes *behind* the ScrollView rather than beside it in
            // a ZStack: as a ZStack sibling its ignoresSafeArea() stretched the
            // stack past the tab bar, the ScrollView inherited that height, and
            // on device it stopped being scrollable at all — the cards past the
            // first screenful were simply drawn below the bottom of the display.
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    dailySection
                    quizSection
                    gamesSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                // The tab bar floats over the scroll content and SwiftUI adds no
                // inset for it here, so the last card needs its own room —
                // otherwise the scroll ends with it tucked under the bar.
                .padding(.bottom, 100)
            }
            .background(Theme.softBackground.ignoresSafeArea())
            .navigationTitle(Text(loc: "Games"))
            // Fire from onAppear rather than .task so a parent-view rebuild
            // (Session/PremiumStore publishing early) can't cancel the request
            // before it lands. The detached Task is retained by the runtime.
            .onAppear { Task { await load() } }
            .refreshable { await load() }
            .sheet(item: $lockedGame) { game in
                PaywallView(trigger: .game(game.title))
            }
        }
    }

    private var dailySection: some View {
        Group {
            if let daily {
                NavigationLink {
                    DailyQuizView(onAnswered: { Task { await loadDaily() } })
                } label: {
                    DailyQuestionCard(daily: daily, partnerName: partnerName)
                }
                .buttonStyle(.plain)
            } else if let dailyError {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc: "Daily question unavailable")
                        .font(.subheadline.bold()).foregroundStyle(Theme.ink)
                    Text(dailyError)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(3)
                    Button(loc: "Retry") { Task { await loadDaily() } }
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: Quiz

    private var quizSection: some View {
        NavigationLink {
            QuizCategoriesView()
        } label: {
            QuizEntryCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Games", subtitle: "Play together, at your own pace")

            ForEach(GameDef.all) { game in
                if premium.isGameLocked(game.id) {
                    Button {
                        Haptics.tap()
                        lockedGame = game
                    } label: {
                        GameCard(game: game, locked: true)
                    }
                    .buttonStyle(.plain)
                } else {
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
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold()).foregroundStyle(Theme.ink)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func load() async {
        await loadDaily()
    }

    private func loadDaily() async {
        do {
            daily = try await APIClient.shared.getDailyQuiz()
            dailyError = nil
        } catch is CancellationError {
            return
        } catch let e as URLError where e.code == .cancelled {
            return
        } catch {
            daily = nil
            dailyError = describe(error)
        }
    }

    private func describe(_ error: Error) -> String {
        if let apiErr = error as? APIErrorResponse { return apiErr.error }
        switch error {
        case let DecodingError.keyNotFound(key, ctx):
            return "missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case let DecodingError.valueNotFound(_, ctx):
            return "null value at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case let DecodingError.typeMismatch(type, ctx):
            return "type mismatch (\(type)) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case let DecodingError.dataCorrupted(ctx):
            return "corrupted: \(ctx.debugDescription)"
        default:
            return error.localizedDescription
        }
    }
}

/// The hero card at the top of Games: today's rotating question, category-coloured.
struct DailyQuestionCard: View {
    let daily: QuizDaily
    var partnerName = "Your partner"

    var body: some View {
        let accent = QuizPalette.accent(daily.colorKey)
        let answered = daily.question.myAnswer != nil
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(loc: "QUESTION OF THE DAY", systemImage: "sparkles")
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
            if daily.question.isMyTurn {
                YourTurnHint(partnerName: partnerName, accent: accent)
            }
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
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
    }
}

/// Topic card with emoji, title, and a colored progress bar (Couple Joy style).
struct CategoryCard: View {
    let category: QuizCategorySummary
    var locked = false
    var partnerName = "Your partner"

    var body: some View {
        let accent = QuizPalette.accent(category.colorKey)
        HStack(spacing: 16) {
            QuizIconTile(systemName: locked ? "lock.fill" : category.icon, colorKey: category.colorKey)
            VStack(alignment: .leading, spacing: 8) {
                Text(category.title).font(.headline).foregroundStyle(Theme.ink)
                if locked {
                    Text(loc: "\(category.quizCount) quizzes · Premium")
                        .font(.caption.bold()).foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // The bar is the couple's: a quiz answered by one of us is
                    // worth half, and only fills up once both have answered.
                    HStack(spacing: 10) {
                        ProgressBar(value: category.progress, accent: accent)
                        Text(loc: "\(Int((category.progress * 100).rounded()))%")
                            .font(.caption.bold()).foregroundStyle(accent)
                    }
                    if category.waitingForMe > 0 {
                        Label(loc: "\(category.waitingForMe) waiting for you", systemImage: "arrow.right.circle.fill")
                            .font(.caption2.bold()).foregroundStyle(accent)
                    } else if let theirs = category.partnerCompletedCount {
                        Text(loc: "You \(category.completedCount)/\(category.quizCount) · \(partnerName) \(theirs)/\(category.quizCount)")
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
            if locked {
                PremiumLockBadge(compact: true)
            } else if category.progress >= 1 {
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

/// Single card that stands in for the whole Quiz section, matching the game
/// cards. Tapping it opens the full list of quiz topic packs.
struct QuizEntryCard: View {
    var body: some View {
        let accent = QuizPalette.accent("purple")
        VStack(alignment: .leading, spacing: 14) {
            QuizIconTile(systemName: "square.grid.2x2.fill", colorKey: "purple", size: 52)

            Text(loc: "Quiz").font(.title3.bold()).foregroundStyle(Theme.ink)

            Text(loc: "Answer privately, then compare — topic packs from cute to deep, plus a daily question.")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(loc: "Browse quizzes").font(.subheadline.bold()).foregroundStyle(accent)
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(accent)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

struct ProgressBar: View {
    let value: Double   // 0...1
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface).frame(height: 8)
                Capsule().fill(accent)
                    .frame(width: max(0, min(1, value)) * geo.size.width, height: 8)
            }
        }
        .frame(height: 8)
    }
}
