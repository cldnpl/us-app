import SwiftUI

struct DailyQuestionView: View {
    @EnvironmentObject var session: Session
    @State private var question: DailyQuestion?
    @State private var draft = ""
    @State private var editing = false
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    if let q = question {
                        Text("💭").font(.system(size: 40))
                        Text(q.question)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        if let mine = q.myAnswer, !editing {
                            answerCard(name: "You", answer: mine)
                            if let partner = q.partnerAnswer {
                                answerCard(name: session.partner?.displayName ?? "Partner", answer: partner)
                            } else {
                                Text("Waiting for \(session.partner?.displayName ?? "your partner") to answer…")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Button("Change my answer") {
                                draft = mine
                                editing = true
                            }
                            .font(.footnote)
                        } else {
                            TextField("Your answer", text: $draft, axis: .vertical)
                                .lineLimit(2...5)
                                .padding(12)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                            Button {
                                Task { await submit() }
                            } label: {
                                if submitting { ProgressView() } else { Text("Submit") }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                        }

                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                        }
                    } else {
                        ProgressView().padding(.top, 60)
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("Daily Question")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func answerCard(name: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.caption.bold()).foregroundStyle(Theme.coral)
            Text(answer).font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        do { question = try await APIClient.shared.getDailyQuestion() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }

    private func submit() async {
        submitting = true
        errorMessage = nil
        defer { submitting = false }
        do {
            try await APIClient.shared.answerDailyQuestion(draft.trimmingCharacters(in: .whitespaces))
            editing = false
            Haptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
