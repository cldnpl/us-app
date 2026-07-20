import SwiftUI

// MARK: - Pack list

struct DebatePackListView: View {
    @State private var packs: [DebatePackSummary] = []
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
                    LazyVStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose a topic to debate!")
                                .font(.title2.bold()).foregroundStyle(Theme.ink)
                            Text("Pick a pack — you'll each argue a side and an AI judge crowns a winner.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2)

                        ForEach(packs) { pack in
                            NavigationLink {
                                DebatePlayView(packId: pack.id, colorKey: pack.colorKey)
                            } label: {
                                DebatePackCard(pack: pack)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Couples Debate")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { packs = try await APIClient.shared.getDebatePacks() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }
}

struct DebatePackCard: View {
    let pack: DebatePackSummary

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
                Text("\(pack.roundCount) rounds").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if pack.bothDone {
                Label("Results", systemImage: "trophy.fill").font(.caption.bold()).foregroundStyle(accent)
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

// MARK: - Round pieces

/// "YOU'RE ARGUING FOR / AGAINST" banner above the motion.
struct DebateSidePill: View {
    let forSide: Bool

    var body: some View {
        Text("YOU'RE ARGUING \(forSide ? "FOR" : "AGAINST")")
            .font(.caption.bold()).tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(forSide ? Theme.coral : Theme.rose, in: Capsule())
    }
}

/// One side's case in the results reveal: who argued, the judge's score, the text.
struct DebateArgumentBlock: View {
    let title: String
    let text: String?
    let score: Int?
    let highlight: Bool
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption2.bold()).foregroundStyle(.secondary)
                Spacer()
                if let score {
                    Text("\(score)/10").font(.caption2.bold())
                        .foregroundStyle(highlight ? accent : .secondary)
                }
            }
            Text(text ?? "—").font(.footnote).foregroundStyle(Theme.ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(highlight ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Play

struct DebatePlayView: View {
    let packId: String
    var colorKey: String = "blue"
    @EnvironmentObject var session: Session

    @State private var pack: DebatePackDetail?
    @State private var index = 0
    @State private var draft = ""
    @State private var showResults = false
    @State private var submitting = false
    @State private var errorMessage: String?
    @FocusState private var editing: Bool

    private var partnerName: String { session.partner?.displayName ?? "your partner" }
    private var accent: Color { QuizPalette.accent(colorKey) }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let pack {
                if showResults { resultsScreen(pack) } else { roundScreen(pack) }
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(pack?.title ?? "Debate")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: round

    @ViewBuilder
    private func roundScreen(_ pack: DebatePackDetail) -> some View {
        let round = pack.rounds[min(index, pack.rounds.count - 1)]
        let forSide = round.mySide == "for"
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    StepDots(total: pack.rounds.count, index: index, accent: accent) {
                        pack.rounds[$0].myArgument != nil
                    }
                    .padding(.top, 12)

                    DebateSidePill(forSide: forSide)

                    Text("“\(round.motion)”")
                        .font(.title2.bold()).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink).padding(.horizontal)

                    Text(forSide
                         ? "Convince the judge this is true."
                         : "Convince the judge this is false.")
                        .font(.subheadline).foregroundStyle(.secondary)

                    ZStack(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text("Make your case…")
                                .font(.body).foregroundStyle(.secondary)
                                .padding(.horizontal, 16).padding(.vertical, 16)
                        }
                        TextEditor(text: $draft)
                            .focused($editing)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .padding(8)
                    }
                    .background(Color(.secondarySystemBackground).opacity(0.6),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
                }
                .padding(20)
            }
            navBar()
        }
    }

    private func navBar() -> some View {
        let isLast = index == (pack?.rounds.count ?? 1) - 1
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
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submitting)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.thinMaterial)
    }

    // MARK: results

    @ViewBuilder
    private func resultsScreen(_ pack: DebatePackDetail) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                if pack.bothDone {
                    VStack(spacing: 10) {
                        Image(systemName: crownIcon(pack.overallWinner))
                            .font(.system(size: 54)).foregroundStyle(accent).padding(.top, 12)
                        Text(crownTitle(pack.overallWinner))
                            .font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("\(pack.myWins)–\(pack.partnerWins) · you vs \(partnerName)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(pack.rounds) { revealRow($0) }
                } else {
                    VStack(spacing: 14) {
                        QuizIconTile(systemName: "hourglass", colorKey: colorKey, size: 72).padding(.top, 40)
                        Text("Waiting for the rebuttal").font(.title2.bold()).foregroundStyle(Theme.ink)
                        Text("Your case is locked in! The judge scores each round once \(partnerName) argues back.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    ForEach(pack.rounds) { pendingRow($0) }
                }
                Button { Task { await reload() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise").font(.subheadline.bold())
                }
                .foregroundStyle(accent).padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func revealRow(_ round: DebateRound) -> some View {
        let iWon = round.roundWinner == "me"
        return VStack(alignment: .leading, spacing: 10) {
            Text("“\(round.motion)”").font(.subheadline.bold()).foregroundStyle(Theme.ink)

            DebateArgumentBlock(title: "You (\(round.mySide == "for" ? "for" : "against"))",
                                text: round.myArgument, score: round.myScore,
                                highlight: round.roundWinner == "me", accent: accent)
            DebateArgumentBlock(title: "\(partnerName) (\(round.mySide == "for" ? "against" : "for"))",
                                text: round.partnerArgument, score: round.partnerScore,
                                highlight: round.roundWinner == "partner", accent: accent)

            if let verdict = round.verdict {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: round.roundWinner == "tie" ? "equal.circle.fill" : (iWon ? "trophy.fill" : "flag.checkered"))
                        .foregroundStyle(accent)
                    Text(verdict).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient(colorKey).opacity(iWon ? 0.6 : 0.3),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func pendingRow(_ round: DebateRound) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("“\(round.motion)”").font(.subheadline.bold()).foregroundStyle(Theme.ink)
            Text("You argued \(round.mySide == "for" ? "for" : "against")")
                .font(.caption2.bold()).foregroundStyle(.secondary)
            Text(round.myArgument ?? "—").font(.footnote).foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuizPalette.gradient(colorKey).opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func crownIcon(_ winner: String?) -> String {
        switch winner {
        case "me": return "crown.fill"
        case "partner": return "flag.checkered"
        default: return "equal.circle.fill"
        }
    }

    private func crownTitle(_ winner: String?) -> String {
        switch winner {
        case "me": return "You won the debate! 🏆"
        case "partner": return "\(partnerName) took this one 😅"
        default: return "It's a draw — great match! 🤝"
        }
    }

    // MARK: actions

    private func back() { guard index > 0 else { return }; withAnimation { index -= 1 }; syncDraft() }

    private func syncDraft() { draft = pack?.rounds[safe: index]?.myArgument ?? "" }

    private func next(isLast: Bool) async {
        let argument = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !argument.isEmpty else { return }
        submitting = true; errorMessage = nil
        editing = false
        defer { submitting = false }
        do {
            let round = pack!.rounds[index]
            try await APIClient.shared.argueDebate(packId, roundId: round.id, argument: argument)
            Haptics.success()
            pack = try await APIClient.shared.getDebatePack(packId)
            if isLast { withAnimation { showResults = true } }
            else { withAnimation { index += 1 }; syncDraft() }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func load() async {
        do {
            let p = try await APIClient.shared.getDebatePack(packId)
            pack = p
            if p.myDone { showResults = true }
            else if let first = p.rounds.firstIndex(where: { $0.myArgument == nil }) { index = first }
            syncDraft()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func reload() async { pack = try? await APIClient.shared.getDebatePack(packId) }
}
