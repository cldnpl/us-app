import SwiftUI

/// Play flow for a quiz: pick (or write) an answer per question — the choice is
/// changeable until you tap "Next". Answers are saved as you advance. After the
/// last question you land on a results screen: a full comparison once your
/// partner has finished too, otherwise a "waiting for results" state.
struct QuizPlayView: View {
    let quizId: String
    var colorKey: String = "pink"
    @EnvironmentObject var session: Session

    @State private var quiz: QuizDetail?
    @State private var index = 0
    @State private var selection: String?   // current question's pending pick
    @State private var draft = ""
    @State private var showResults = false
    @State private var submitting = false
    @State private var errorMessage: String?

    private var partnerName: String { session.partner?.displayName ?? "your partner" }
    private var accent: Color { QuizPalette.accent(colorKey) }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let quiz {
                if showResults {
                    resultsScreen(quiz)
                } else {
                    questionScreen(quiz)
                }
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(quiz?.title ?? "Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Question screen

    @ViewBuilder
    private func questionScreen(_ quiz: QuizDetail) -> some View {
        let q = quiz.questions[min(index, quiz.questions.count - 1)]
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 22) {
                    QuizIconTile(systemName: quiz.icon, colorKey: colorKey, size: 60).padding(.top, 8)

                    HStack(spacing: 6) {
                        ForEach(quiz.questions.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? accent : (quiz.questions[i].myAnswer != nil ? accent.opacity(0.4) : Color.secondary.opacity(0.2)))
                                .frame(width: i == index ? 22 : 8, height: 8)
                        }
                    }
                    Text("Question \(index + 1) of \(quiz.questions.count)")
                        .font(.caption.bold()).foregroundStyle(.secondary)

                    Text(q.prompt)
                        .font(.title2.bold()).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink).padding(.horizontal)

                    inputSection(q)

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            navBar(q)
        }
    }

    @ViewBuilder
    private func inputSection(_ q: QuizQuestion) -> some View {
        if q.isChoice, let options = q.options {
            if q.hasPhotos {
                VStack(spacing: 14) {
                    ForEach(options) { o in
                        Button { toggle(o.label) } label: {
                            PhotoChoiceCard(option: o, colorKey: colorKey, selected: selection == o.label)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(options) { o in
                        Button { toggle(o.label) } label: {
                            IconChoiceRow(option: o, colorKey: colorKey, selected: selection == o.label)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
    }

    private func navBar(_ q: QuizQuestion) -> some View {
        let isLast = index == (quiz?.questions.count ?? 1) - 1
        let ready = (selection?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        return HStack(spacing: 14) {
            if index > 0 {
                Button { back() } label: {
                    Label("Back", systemImage: "chevron.left").font(.subheadline.bold())
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await next(isLast: isLast) } } label: {
                if submitting { ProgressView() }
                else { Label(isLast ? "Finish" : "Next", systemImage: isLast ? "checkmark" : "chevron.right") }
            }
            .buttonStyle(PillButtonStyle(color: accent))
            .disabled(!ready || submitting)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.thinMaterial)
    }

    // MARK: - Results / waiting screen

    @ViewBuilder
    private func resultsScreen(_ quiz: QuizDetail) -> some View {
        let partnerDone = quiz.questions.allSatisfy { $0.partnerAnswer != nil }
        ScrollView {
            VStack(spacing: 18) {
                if partnerDone {
                    let matches = quiz.questions.filter { $0.myAnswer != nil && $0.myAnswer == $0.partnerAnswer }.count
                    VStack(spacing: 8) {
                        QuizIconTile(systemName: "checkmark.seal.fill", colorKey: colorKey, size: 64)
                        Text("Results").font(.title.bold()).foregroundStyle(Theme.ink)
                        if quiz.questions.contains(where: { $0.isChoice }) {
                            Text("You matched on \(matches) of \(quiz.questions.count)")
                                .font(.headline).foregroundStyle(accent)
                        }
                    }
                    .padding(.top, 12)

                    ForEach(quiz.questions) { q in
                        resultRow(q)
                    }
                } else {
                    VStack(spacing: 14) {
                        QuizIconTile(systemName: "hourglass", colorKey: colorKey, size: 72).padding(.top, 40)
                        Text("Waiting for results").font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("You've answered them all! We'll show how you compare once \(partnerName) finishes this quiz too.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                }

                Button { Task { await reload() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").font(.subheadline.bold())
                }
                .foregroundStyle(accent).padding(.top, 8)

                Button("Review my answers") { withAnimation { index = 0; syncSelection(); showResults = false } }
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func resultRow(_ q: QuizQuestion) -> some View {
        let match = q.myAnswer != nil && q.myAnswer == q.partnerAnswer
        return VStack(alignment: .leading, spacing: 12) {
            Text(q.prompt).font(.subheadline.bold()).foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                miniAnswer("You", q.option(for: q.myAnswer), q.myAnswer, Theme.coral)
                miniAnswer(partnerName, q.option(for: q.partnerAnswer), q.partnerAnswer, Theme.rose)
            }
            if q.isChoice {
                Label(match ? "You match!" : "Different picks", systemImage: match ? "heart.fill" : "sparkles")
                    .font(.caption.bold()).foregroundStyle(match ? Theme.coral : .secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient(colorKey).opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func miniAnswer(_ name: String, _ option: QuizOption?, _ fallback: String?, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.caption2.bold()).foregroundStyle(tint)
            if let url = option?.imageURL {
                AsyncImage(url: url) { p in
                    if let img = p.image { img.resizable().scaledToFill() } else { Color.secondary.opacity(0.15) }
                }
                .frame(height: 64).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(spacing: 5) {
                if let sf = option?.icon { Image(systemName: sf).font(.caption).foregroundStyle(tint) }
                Text(option?.label ?? fallback ?? "—").font(.footnote).foregroundStyle(Theme.ink).lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func toggle(_ label: String) {
        selection = (selection == label) ? nil : label
        Haptics.tap(.light)
    }

    private func syncSelection() {
        let q = quiz?.questions[safe: index]
        selection = q?.myAnswer
        draft = q?.myAnswer ?? ""
    }

    private func back() {
        guard index > 0 else { return }
        withAnimation { index -= 1 }
        syncSelection()
    }

    private func next(isLast: Bool) async {
        guard let answer = selection?.trimmingCharacters(in: .whitespacesAndNewlines), !answer.isEmpty else { return }
        submitting = true; errorMessage = nil
        defer { submitting = false }
        do {
            let q = quiz!.questions[index]
            try await APIClient.shared.answerQuiz(quizId, questionId: q.id, answer: answer)
            Haptics.success()
            quiz = try await APIClient.shared.getQuiz(quizId)  // keep answers fresh
            if isLast {
                withAnimation { showResults = true }
            } else {
                withAnimation { index += 1 }
                syncSelection()
            }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func load() async {
        do {
            let q = try await APIClient.shared.getQuiz(quizId)
            quiz = q
            if q.questions.allSatisfy({ $0.myAnswer != nil }) {
                showResults = true          // already completed → straight to results
            } else if let first = q.questions.firstIndex(where: { $0.myAnswer == nil }) {
                index = first
            }
            syncSelection()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func reload() async {
        quiz = try? await APIClient.shared.getQuiz(quizId)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

/// Pill-shaped primary action button used in the quiz nav bar.
struct PillButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 26).padding(.vertical, 12)
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

/// Big full-width photo option with a gradient scrim, label, and selected state.
struct PhotoChoiceCard: View {
    let option: QuizOption
    var colorKey: String = "pink"
    var selected: Bool = false

    var body: some View {
        let accent = QuizPalette.accent(colorKey)
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: option.imageURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                case .empty: ZStack { Color.secondary.opacity(0.12); ProgressView() }
                default:
                    ZStack {
                        LinearGradient(colors: QuizPalette.colors(colorKey), startPoint: .top, endPoint: .bottom)
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(height: 150).frame(maxWidth: .infinity).clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            HStack {
                Text(option.label).font(.title3.bold()).foregroundStyle(.white).shadow(radius: 4)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.title2)
                        .foregroundStyle(.white).shadow(radius: 4)
                }
            }
            .padding(16)
        }
        .frame(height: 150).frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(selected ? accent : Theme.hairline, lineWidth: selected ? 4 : 1))
        .shadow(color: .black.opacity(selected ? 0.15 : 0.08), radius: 8, y: 4)
    }
}

/// A tappable option row with an SF Symbol, label, and selected state.
struct IconChoiceRow: View {
    let option: QuizOption
    let colorKey: String
    var selected: Bool = false

    var body: some View {
        let accent = QuizPalette.accent(colorKey)
        HStack(spacing: 16) {
            Image(systemName: option.icon ?? "circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(selected ? .white : accent)
                .frame(width: 44, height: 44)
                .background(selected ? accent : accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(option.label).font(.headline).foregroundStyle(Theme.ink)
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(selected ? accent : .clear, lineWidth: 2))
    }
}
