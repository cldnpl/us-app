import SwiftUI

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
                    .foregroundStyle(Theme.rose)
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
                    .foregroundStyle(Theme.rose)
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
    @State private var connecting = false

    var body: some View {
        Form {
            switch cycle.userHasCycle {
            case nil:            askSection
            case .some(true):    selfSections
            case .some(false):   partnerSections
            }
            aboutSection
        }
        .navigationTitle("Cycle & health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await cycle.refreshOnAppear()
            level = cycle.shareLevel
        }
    }

    // MARK: Not answered yet → ask

    private var askSection: some View {
        Section("Cycle & health") {
            Text("Do you have a menstrual cycle? This tailors Us. — track your own, or get gentle tips to support your partner's.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Yes, I have a cycle") { cycle.setUserHasCycle(true) }
            Button("No — I want to support \(partnerName)") { cycle.setUserHasCycle(false) }
        }
    }

    // MARK: She has a cycle → track + share

    @ViewBuilder
    private var selfSections: some View {
        Section("Your cycle") {
            if !HealthKitManager.shared.isAvailable {
                Text("Apple Health isn't available on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else if let i = cycle.insights {
                Label(i.phase.title, systemImage: i.phase.symbol)
                LabeledContent("Cycle day", value: "\(i.cycleDay)")
                LabeledContent("Next period", value: i.predictedNextPeriod.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Cycle length", value: "~\(i.cycleLength) days")
                Text(i.phase.detail + (i.isEstimated ? " Estimate improves as Apple Health learns your cycle." : ""))
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Button {
                    Task { connecting = true; await cycle.connectHealth(); level = cycle.shareLevel; connecting = false }
                } label: {
                    HStack {
                        Label("Connect Apple Health", systemImage: "heart.text.square")
                        if connecting { Spacer(); ProgressView() }
                    }
                }
                .disabled(connecting)
                Text("Us reads your cycle from Apple Health — whatever you track in Flo, Clue, or Health syncs here. It stays on your phone until you choose to share below.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }

        if cycle.insights != nil {
            Section {
                Picker("Share with \(partnerName)", selection: $level) {
                    ForEach(CycleShareLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Text(level.explanation(partnerName: partnerName))
                    .font(.footnote).foregroundStyle(.secondary)
            } header: {
                Text("Sharing")
            } footer: {
                Text("Only a coarse phase\(level == .full ? " and day count" : "") is ever shared — never your symptoms. Turn it off anytime.")
            }
            .onChange(of: level) { newValue in
                Task { await cycle.setShareLevel(newValue) }
            }
        }
    }

    // MARK: He supports her → her phase + a checklist of tips

    @ViewBuilder
    private var partnerSections: some View {
        if let partner = cycle.partner, partner.sharing,
           let phase = CyclePhase(rawValue: partner.phase ?? "") {
            Section("\(partnerName)'s cycle") {
                Label(phase.title, systemImage: phase.symbol)
                if let day = partner.cycleDay { LabeledContent("Cycle day", value: "\(day)") }
                if let days = partner.periodInDays {
                    LabeledContent("Next period", value: days <= 0 ? "around now" : "~\(days) days")
                }
                Text(phase.detail).font(.footnote).foregroundStyle(.secondary)
            }
            Section("How to support her now") {
                ForEach(phase.partnerTips, id: \.self) { tip in
                    Label {
                        Text(tip).font(.subheadline)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.rose)
                    }
                }
            }
        } else {
            Section("\(partnerName)'s cycle") {
                Text("When \(partnerName) turns on cycle sharing in her Us., you'll see her current phase here — plus simple, kind things you can do to support her.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: About / mode switch

    private var aboutSection: some View {
        Section {
            Text("Predictions are estimates, not medical advice. Us never stores health data — it reads from Apple Health on the device, and only the phase she chooses ever leaves it.")
                .font(.caption).foregroundStyle(.secondary)
            if let has = cycle.userHasCycle {
                Button(has ? "I don't have a cycle" : "I have a cycle") {
                    cycle.setUserHasCycle(!has)
                }
                .font(.footnote)
            }
        }
    }

    private var partnerName: String {
        (session.partner?.displayName).flatMap { $0.isEmpty ? nil : $0 } ?? "your partner"
    }
}
