import SwiftUI

// MARK: - Pack list

struct HwdykmPackListView: View {
    @State private var packs: [HwdykmPackSummary] = []
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                if packs.isEmpty && errorMessage == nil {
                    ProgressView().padding(.top, 60)
                } else if let errorMessage, packs.isEmpty {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary).padding(.top, 60)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(packs) { pack in
                            NavigationLink {
                                HwdykmPlayView(packId: pack.id, colorKey: pack.colorKey)
                            } label: {
                                HwdykmPackCard(pack: pack)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Know Me")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { packs = try await APIClient.shared.getHwdykmPacks() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }
}

struct HwdykmPackCard: View {
    let pack: HwdykmPackSummary

    var body: some View {
        let accent = QuizPalette.accent(pack.colorKey)
        HStack(spacing: 16) {
            QuizIconTile(systemName: pack.icon, colorKey: pack.colorKey)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(pack.title).font(.headline).foregroundStyle(Theme.ink)
                    if !pack.tag.isEmpty {
                        Text(pack.tag).font(.caption2.bold()).foregroundStyle(accent)
                    }
                }
                Text("\(pack.questionCount) questions").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if pack.bothDone {
                Label("Results", systemImage: "checkmark.seal.fill").font(.caption.bold()).foregroundStyle(accent)
            } else if pack.myDone {
                Label("Waiting", systemImage: "hourglass").font(.caption.bold()).foregroundStyle(accent)
            } else {
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient(pack.colorKey), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

// MARK: - Play

struct HwdykmPlayView: View {
    let packId: String
    var colorKey: String = "pink"
    @EnvironmentObject var session: Session

    @State private var pack: HwdykmPackDetail?
    @State private var index = 0
    @State private var selection: String?
    @State private var showResults = false
    @State private var submitting = false
    @State private var errorMessage: String?

    private var partnerName: String { session.partner?.displayName ?? "your partner" }
    private var accent: Color { QuizPalette.accent(colorKey) }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let pack {
                if showResults { resultsScreen(pack) } else { questionScreen(pack) }
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(pack?.title ?? "Know Me")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func questionScreen(_ pack: HwdykmPackDetail) -> some View {
        let q = pack.questions[min(index, pack.questions.count - 1)]
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    StepDots(total: pack.questions.count, index: index, accent: accent) {
                        pack.questions[$0].myAnswer != nil
                    }
                    .padding(.top, 12)

                    HwdykmRolePill(subjectIsMe: q.subjectIsMe, partnerName: partnerName)

                    Text(q.prompt)
                        .font(.title2.bold()).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink).padding(.horizontal)

                    VStack(spacing: 12) {
                        ForEach(q.options, id: \.self) { opt in
                            Button { selection = (selection == opt) ? nil : opt; Haptics.tap(.light) } label: {
                                HwdykmOptionRow(text: opt, selected: selection == opt, accent: accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                }
                .padding(20)
            }
            navBar()
        }
    }

    private func navBar() -> some View {
        let isLast = index == (pack?.questions.count ?? 1) - 1
        return HStack(spacing: 14) {
            if index > 0 {
                Button { back() } label: { Label("Back", systemImage: "chevron.left").font(.subheadline.bold()) }
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { Task { await next(isLast: isLast) } } label: {
                if submitting { ProgressView() }
                else { Label(isLast ? "Finish" : "Next", systemImage: isLast ? "checkmark" : "chevron.right") }
            }
            .buttonStyle(PillButtonStyle(color: accent))
            .disabled(selection == nil || submitting)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.thinMaterial)
    }

    // MARK: results

    @ViewBuilder
    private func resultsScreen(_ pack: HwdykmPackDetail) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if pack.bothDone {
                    let matches = pack.questions.filter { $0.matched }.count
                    VStack(spacing: 10) {
                        ScoreRing(score: pack.score, color: accent).padding(.top, 12)
                        Text(pack.score >= 70 ? "You really know each other! 💖" : pack.score >= 40 ? "Not bad — room to learn 😊" : "Opposites attract 😅")
                            .font(.headline).foregroundStyle(Theme.ink)
                        Text("Matched on \(matches) of \(pack.questions.count)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(pack.questions) { revealRow($0) }
                } else {
                    VStack(spacing: 14) {
                        QuizIconTile(systemName: "hourglass", colorKey: colorKey, size: 72).padding(.top, 40)
                        Text("Waiting for results").font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("You're all locked in! We'll reveal your compatibility once \(partnerName) finishes this pack too.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                }
                Button { Task { await reload() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").font(.subheadline.bold())
                }
                .foregroundStyle(accent).padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func revealRow(_ q: HwdykmQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(q.prompt).font(.subheadline.bold()).foregroundStyle(Theme.ink)
            Text(q.subjectIsMe ? "About you" : "About \(partnerName)")
                .font(.caption2.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: q.matched ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(q.matched ? Theme.coral : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Real answer: \(q.honestAnswer ?? "—")").font(.footnote).foregroundStyle(Theme.ink)
                    Text("Guess: \(q.guess ?? "—")").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient(colorKey).opacity(q.matched ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: actions

    private func back() { guard index > 0 else { return }; withAnimation { index -= 1 }; syncSelection() }

    private func syncSelection() { selection = pack?.questions[safe: index]?.myAnswer }

    private func next(isLast: Bool) async {
        guard let answer = selection, !answer.isEmpty else { return }
        submitting = true; errorMessage = nil
        defer { submitting = false }
        do {
            let q = pack!.questions[index]
            try await APIClient.shared.answerHwdykm(packId, questionId: q.id, answer: answer)
            Haptics.success()
            pack = try await APIClient.shared.getHwdykmPack(packId)
            if isLast { withAnimation { showResults = true } }
            else { withAnimation { index += 1 }; syncSelection() }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func load() async {
        do {
            let p = try await APIClient.shared.getHwdykmPack(packId)
            pack = p
            if p.myDone { showResults = true }
            else if let first = p.questions.firstIndex(where: { $0.myAnswer == nil }) { index = first }
            syncSelection()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func reload() async { pack = try? await APIClient.shared.getHwdykmPack(packId) }
}

// MARK: - Small pieces

/// "ANSWER HONESTLY" / "GUESS <partner>'S ANSWER" banner above the prompt.
struct HwdykmRolePill: View {
    let subjectIsMe: Bool
    let partnerName: String

    var body: some View {
        Text(subjectIsMe ? "ANSWER HONESTLY" : "GUESS \(partnerName.uppercased())'S ANSWER")
            .font(.caption.bold()).tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(subjectIsMe ? Theme.coral : Theme.rose, in: Capsule())
    }
}

struct HwdykmOptionRow: View {
    let text: String
    let selected: Bool
    let accent: Color

    var body: some View {
        HStack {
            Text(text).font(.headline).foregroundStyle(selected ? .white : Theme.ink)
            Spacer()
            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white) }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? accent : Color(.secondarySystemBackground).opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ScoreRing: View {
    let score: Int      // 0..100
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.001, CGFloat(score) / 100))
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)%").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                Text("match").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 130, height: 130)
    }
}
