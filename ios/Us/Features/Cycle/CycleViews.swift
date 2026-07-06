import SwiftUI

// MARK: - Phase ring

/// The cycle wheel: a colored progress ring (color per phase) with the phase
/// name, current cycle day, and a countdown to the next phase centered inside.
struct PhaseRing: View {
    let phase: CyclePhase
    let cycleDay: Int
    let cycleLength: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(phase.color.opacity(0.16), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(phase.color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                Text(phase.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(phase.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Day \(cycleDay)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(nextPhaseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(38)
        }
        .frame(width: 236, height: 236)
        .animation(.easeInOut(duration: 0.5), value: progress)
    }

    private var progress: Double {
        guard cycleLength > 0 else { return 0.02 }
        return min(1, max(0.02, Double(cycleDay) / Double(cycleLength)))
    }

    private var nextPhaseText: String {
        let next = CycleEngine.phaseProgress(cycleDay: cycleDay, cycleLength: cycleLength)
        if next.daysToNextPhase <= 0 { return "starting \(next.nextPhase.title.lowercased())" }
        let unit = next.daysToNextPhase == 1 ? "day" : "days"
        return "\(next.daysToNextPhase) \(unit) to \(next.nextPhase.title.lowercased())"
    }
}

// MARK: - Home cards

/// Compact card showing *your own* cycle (people who have one). Tapping opens
/// the detail screen.
struct SelfCycleCard: View {
    let insights: CycleInsights

    var body: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: insights.phase.symbol)
                    .font(.system(size: 26))
                    .foregroundStyle(insights.phase.color)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(insights.phase.title).font(.headline)
                    Text("Day \(insights.cycleDay) · next period \(nextPeriodText)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
    }

    private var nextPeriodText: String {
        switch insights.daysUntilNextPeriod {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(insights.daysUntilNextPeriod) days"
        }
    }
}

/// "His" card — for a partner who doesn't have a cycle. Shows her current phase
/// and the first supportive tip, or a prompt when she isn't sharing yet.
struct PartnerPeriodCard: View {
    let partner: PartnerCycle?
    let partnerName: String

    var body: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: phase?.symbol ?? "heart.text.square.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(phase?.color ?? Theme.rose)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    if let phase {
                        Text("\(partnerName) · \(phase.title)").font(.headline)
                        Text(phase.partnerTips.first ?? phase.partnerHint)
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    } else {
                        Text("Check \(partnerName)'s cycle").font(.headline)
                        Text("Gentle tips to support her — once she shares her cycle.")
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
    }

    private var phase: CyclePhase? {
        guard let partner, partner.sharing, let raw = partner.phase else { return nil }
        return CyclePhase(rawValue: raw)
    }
}

/// Neutral entry shown on Home when tracking isn't set up yet (or the "do you
/// have a cycle?" question hasn't been answered). Opens the detail/setup screen.
struct CycleSetupCard: View {
    var body: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cycle & health").font(.headline)
                    Text("Track your cycle, or get tips to support your partner's.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Detail / settings screen

struct CycleDetailView: View {
    @EnvironmentObject var session: Session
    @StateObject private var cycle = CycleManager.shared
    @State private var level: CycleShareLevel = .off
    @State private var noteText = ""
    @State private var connecting = false

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    switch cycle.userHasCycle {
                    case nil:          askCard
                    case .some(true):  selfContent
                    case .some(false): partnerContent
                    }
                    privacyNote
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Cycle & health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cycle.refreshOnAppear()
            level = cycle.shareLevel
            noteText = cycle.todayNote
        }
        .onChange(of: noteText) { cycle.saveNote($0) }
        .onDisappear { Task { await cycle.syncNoteIfSharing() } }
    }

    // MARK: Not answered yet → ask

    private var askCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Cycle & health").font(.headline)
                Text("Do you have a menstrual cycle? This tailors Us. — track your own, or get gentle tips to support your partner's.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Yes, I have a cycle") { withAnimation { cycle.setUserHasCycle(true) } }
                    .buttonStyle(PrimaryButtonStyle())
                Button("No — I want to support \(partnerName)") { withAnimation { cycle.setUserHasCycle(false) } }
                    .font(.subheadline).foregroundStyle(Theme.rose)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: She has a cycle → ring, note, share

    @ViewBuilder
    private var selfContent: some View {
        if !HealthKitManager.shared.isAvailable {
            infoCard("Apple Health isn't available on this device.")
        } else if let i = cycle.insights {
            VStack(spacing: 12) {
                PhaseRing(phase: i.phase, cycleDay: i.cycleDay, cycleLength: i.cycleLength)
                    .padding(.top, 10)
                Text("Next period \(i.predictedNextPeriod.formatted(date: .abbreviated, time: .omitted)) · ~\(i.cycleLength)-day cycle")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
            thoughtsCard
            sharingCard
        } else {
            connectCard
        }
    }

    private var connectCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your cycle").font(.headline)
                Text("Us reads your cycle from Apple Health — whatever you track in Flo, Clue, or Health syncs here. It stays on your phone until you choose to share.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button {
                    Task { connecting = true; await cycle.connectHealth(); level = cycle.shareLevel; connecting = false }
                } label: {
                    if connecting { ProgressView().tint(.white).frame(maxWidth: .infinity) }
                    else { Label("Connect Apple Health", systemImage: "heart.text.square.fill") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(connecting)
            }
        }
    }

    private var thoughtsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today's thoughts").font(.headline)
                    Spacer()
                    Text(Date().formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ZStack(alignment: .topLeading) {
                    if noteText.isEmpty {
                        Text("How are you feeling today? Jot down a thought…")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 8).padding(.leading, 6)
                    }
                    TextEditor(text: $noteText)
                        .font(.subheadline)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(2)
                }
                .background(Theme.rose.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var sharingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sharing").font(.headline)
                HStack {
                    Text("Share with \(partnerName)").font(.subheadline)
                    Spacer()
                    Picker("", selection: $level) {
                        ForEach(CycleShareLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .tint(Theme.rose)
                }
                Text(level.explanation(partnerName: partnerName))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .onChange(of: level) { newValue in Task { await cycle.setShareLevel(newValue) } }
        }
    }

    // MARK: He supports her → her ring, the explainer, tips, her note

    @ViewBuilder
    private var partnerContent: some View {
        if let p = cycle.partner, p.sharing, let phase = CyclePhase(rawValue: p.phase ?? "") {
            if let day = p.cycleDay {
                PhaseRing(phase: phase, cycleDay: day, cycleLength: estimatedLength(day, p.periodInDays))
                    .padding(.top, 10).padding(.bottom, 4)
            }

            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Label(phase.title, systemImage: phase.symbol)
                        .font(.headline).foregroundStyle(phase.color)
                    explainerRow("What's happening", phase.about)
                    explainerRow("What she may feel", phase.symptoms)
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to support her now").font(.headline)
                    ForEach(phase.partnerTips, id: \.self) { tip in
                        Label {
                            Text(tip).font(.subheadline)
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(phase.color)
                        }
                    }
                }
            }

            if let note = p.note, !note.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(partnerName)'s thoughts today").font(.headline)
                        Text(note).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            infoCard("When \(partnerName) turns on cycle sharing in her Us., you'll see her current phase here — plus what it means and simple, kind ways to support her.")
        }

        Button("I have a cycle") { withAnimation { cycle.setUserHasCycle(true) } }
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: Building blocks

    private func explainerRow(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.subheadline.weight(.semibold))
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func infoCard(_ text: String) -> some View {
        Card {
            Text(text)
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// His ring has only what she shares — estimate her cycle length from her
    /// cycle day plus the days-to-next-period she shared (fallback 28).
    private func estimatedLength(_ cycleDay: Int, _ periodInDays: Int?) -> Int {
        guard let periodInDays else { return CycleEngine.defaultCycleLength }
        return min(40, max(21, cycleDay + periodInDays))
    }

    private var privacyNote: some View {
        Text("Predictions are estimates, not medical advice. Us never stores your health data — it reads from Apple Health on your device, and only what you choose ever leaves it.")
            .font(.caption).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 4)
    }

    private var partnerName: String {
        (session.partner?.displayName).flatMap { $0.isEmpty ? nil : $0 } ?? "your partner"
    }
}
