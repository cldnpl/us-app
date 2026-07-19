import SwiftUI

/// Lists the quizzes inside a category (the "Relationship" / "Sex & Love" screen).
struct QuizCategoryDetailView: View {
    let categoryId: String
    let categoryTitle: String
    let categoryIcon: String   // SF Symbol

    @State private var detail: QuizCategoryDetail?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                if let detail {
                    LazyVStack(spacing: 16) {
                        ForEach(detail.quizzes) { quiz in
                            NavigationLink {
                                QuizPlayView(quizId: quiz.id, colorKey: detail.colorKey)
                            } label: {
                                QuizCard(quiz: quiz, colorKey: detail.colorKey)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                } else if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(.top, 60)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
        }
        .navigationTitle(categoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { detail = try await APIClient.shared.getQuizCategory(categoryId) }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }
}

/// One quiz row: tag + format badge, title, emoji, and a play/compare state.
struct QuizCard: View {
    let quiz: QuizSummary
    let colorKey: String

    var body: some View {
        let accent = QuizPalette.accent(colorKey)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if let tag = quiz.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(accent, in: Capsule())
                        }
                        Text(QuizFormat(rawValue: quiz.format)?.badge ?? quiz.format.uppercased())
                            .font(.caption2.bold())
                            .foregroundStyle(accent)
                    }
                    Text(quiz.title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                QuizIconTile(systemName: quiz.icon, colorKey: colorKey)
            }

            HStack {
                Text("\(quiz.questionCount) question\(quiz.questionCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if quiz.myDone {
                    Label(quiz.partnerDone ? "See results" : "Waiting for results",
                          systemImage: quiz.partnerDone ? "checkmark.seal.fill" : "hourglass")
                        .font(.footnote.bold())
                        .foregroundStyle(accent)
                } else {
                    Label("PLAY", systemImage: "play.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient(colorKey), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
