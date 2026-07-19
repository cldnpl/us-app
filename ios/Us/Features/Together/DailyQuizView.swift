import SwiftUI

/// The "Question of the Day": one question that changes daily, drawn from a
/// rotating category (with its colour). Answer independently, then compare.
struct DailyQuizView: View {
    @EnvironmentObject var session: Session
    var onAnswered: (() -> Void)?

    @State private var daily: QuizDaily?
    @State private var selection: String?
    @State private var draft = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private var partnerName: String { session.partner?.displayName ?? "your partner" }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let daily {
                content(daily)
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Question of the Day")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ daily: QuizDaily) -> some View {
        let accent = QuizPalette.accent(daily.colorKey)
        let q = daily.question
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    QuizIconTile(systemName: daily.icon, colorKey: daily.colorKey, size: 64)
                    Text(daily.categoryTitle.uppercased())
                        .font(.caption.bold()).foregroundStyle(accent)
                        .tracking(1)
                    Text(q.prompt)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal)
                }
                .padding(.top, 8)

                if q.myAnswer == nil {
                    inputSection(q)
                } else {
                    compareSection(daily)
                }

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func inputSection(_ q: QuizQuestion) -> some View {
        let key = daily?.colorKey ?? "pink"
        VStack(spacing: 14) {
            if q.isChoice, let options = q.options {
                ForEach(options) { o in
                    Button { selection = (selection == o.label) ? nil : o.label; Haptics.tap(.light) } label: {
                        if q.hasPhotos {
                            PhotoChoiceCard(option: o, colorKey: key, selected: selection == o.label)
                        } else {
                            IconChoiceRow(option: o, colorKey: key, selected: selection == o.label)
                        }
                    }
                    .buttonStyle(.plain).disabled(submitting)
                }
            } else {
                TextField("Your answer", text: $draft, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .onChange(of: draft) { v in
                        selection = v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : v
                    }
            }

            Button {
                Task { await submit(selection ?? "") }
            } label: {
                if submitting { ProgressView() } else { Text("Submit answer") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled((selection?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) || submitting)
        }
    }

    @ViewBuilder
    private func compareSection(_ daily: QuizDaily) -> some View {
        let q = daily.question
        VStack(spacing: 14) {
            answerCard(name: "You", option: q.option(for: q.myAnswer), fallback: q.myAnswer ?? "", accent: Theme.coral)
            if let partner = q.partnerAnswer {
                answerCard(name: partnerName, option: q.option(for: partner), fallback: partner, accent: Theme.rose)
                if q.isChoice {
                    Label(q.myAnswer == partner ? "You match!" : "Different picks",
                          systemImage: q.myAnswer == partner ? "heart.fill" : "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(q.myAnswer == partner ? Theme.coral : .secondary)
                }
            } else {
                Label("Waiting for \(partnerName) to answer…", systemImage: "clock.fill")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Come back tomorrow for a new question 💫")
                .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
        }
    }

    private func answerCard(name: String, option: QuizOption?, fallback: String, accent: Color) -> some View {
        HStack(spacing: 14) {
            if let url = option?.imageURL {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() } else { Color.secondary.opacity(0.15) }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let sf = option?.icon {
                Image(systemName: sf).font(.title3.weight(.semibold)).foregroundStyle(accent)
                    .frame(width: 54, height: 54)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.caption.bold()).foregroundStyle(accent)
                Text(option?.label ?? fallback).font(.body).foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        do { daily = try await APIClient.shared.getDailyQuiz() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }

    private func submit(_ answer: String) async {
        guard !answer.isEmpty else { return }
        submitting = true; errorMessage = nil
        defer { submitting = false }
        do {
            try await APIClient.shared.answerDailyQuiz(answer)
            Haptics.success()
            draft = ""
            daily = try await APIClient.shared.getDailyQuiz()
            onAnswered?()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
