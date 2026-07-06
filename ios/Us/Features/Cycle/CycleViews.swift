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

/// The pregnancy wheel: progress toward 40 weeks, with the current week and a
/// countdown to the due date centered inside.
struct PregnancyRing: View {
    let week: Int
    let daysToDue: Int

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.rose.opacity(0.16), lineWidth: 18)
            Circle()
                .trim(from: 0, to: min(1, max(0.02, Double(week) / 40.0)))
                .stroke(Theme.rose, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text("Week \(week)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.rose)
                Text("of 40")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(daysToDue <= 0 ? "due any day now" : "\(daysToDue) days to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(38)
        }
        .frame(width: 236, height: 236)
        .animation(.easeInOut(duration: 0.5), value: week)
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

/// Home card shown while a pregnancy is active/shared — week + due countdown.
struct PregnancyHomeCard: View {
    let insights: PregnancyInsights
    let title: String

    var body: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: "figure.child.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.rose)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text("Week \(insights.week) · \(insights.daysToDue <= 0 ? "due any day 💛" : "\(insights.daysToDue) days to go")")
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
    @StateObject private var cycle: CycleManager
    @State private var level: CycleShareLevel = .off
    @State private var noteText = ""
    @State private var connecting = false
    @State private var showDuePicker = false
    @State private var pickedDue = Calendar.current.date(byAdding: .month, value: 7, to: Date()) ?? Date()

    init(cycle: CycleManager = .shared) {
        _cycle = StateObject(wrappedValue: cycle)
    }

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
        .sheet(isPresented: $showDuePicker) { dueDateSheet }
    }

    private var dueDateSheet: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("When's your due date?")
                        .font(.title2.bold())
                        .padding(.top, 12)
                    DatePicker("Due date", selection: $pickedDue, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Theme.rose)
                        .padding(.horizontal, 6)
                    Button("Start tracking") {
                        Task { await cycle.startPregnancy(dueDate: pickedDue) }
                        showDuePicker = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDuePicker = false }
                }
            }
        }
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

    // MARK: She has a cycle → cycle tracking, or pregnancy mode

    @ViewBuilder
    private var selfContent: some View {
        if cycle.isPregnant {
            pregnancyContent
        } else {
            cycleContent
            pregnancyEntry
        }
    }

    @ViewBuilder
    private var cycleContent: some View {
        if !HealthKitManager.shared.isAvailable {
            infoCard("Apple Health isn't available on this device.")
        } else if let i = cycle.insights {
            VStack(spacing: 12) {
                PhaseRing(phase: i.phase, cycleDay: i.cycleDay, cycleLength: i.cycleLength)
                    .padding(.top, 10)
                Text("Next period \(i.predictedNextPeriod.formatted(date: .abbreviated, time: .omitted)) · ~\(i.cycleLength)-day cycle")
                    .font(.footnote).foregroundStyle(.secondary)
                    .padding(.top, 20)

            }
            .padding(.bottom, 4)
            thoughtsCard
            sharingCard
        } else {
            connectCard
        }
    }

    // MARK: Pregnancy (her side)

    @ViewBuilder
    private var pregnancyContent: some View {
        if let pg = cycle.pregnancyInsights {
            VStack(spacing: 12) {
                PregnancyRing(week: pg.week, daysToDue: pg.daysToDue)
                    .padding(.top, 10)
                Text("Due \(pg.dueDate.formatted(date: .abbreviated, time: .omitted)) · \(PregnancyEngine.trimesterTitle(pg.trimester))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            Card {
                HStack(spacing: 14) {
                    Image(systemName: "carrot.fill")
                        .font(.system(size: 24)).foregroundStyle(Theme.rose).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This week").font(.headline)
                        Text("Your baby is about the size of \(pg.babySize).")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text(PregnancyEngine.trimesterTitle(pg.trimester)).font(.headline)
                    Text(PregnancyEngine.trimesterAbout(pg.trimester))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            Text("\(partnerName) can see your progress.")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            Button("End pregnancy tracking") { Task { await cycle.endPregnancy() } }
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.top, 2)
        }
    }

    private var pregnancyEntry: some View {
        Button {
            pickedDue = Calendar.current.date(byAdding: .month, value: 7, to: Date()) ?? Date()
            showDuePicker = true
        } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "figure.child.circle.fill")
                        .font(.system(size: 26)).foregroundStyle(Theme.rose).frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Expecting a baby?").font(.headline)
                        Text("Switch to pregnancy tracking.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
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
                Text("Share with \(partnerName)").font(.headline)
                Menu {
                    Picker("", selection: $level) {
                        ForEach(CycleShareLevel.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(level.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.rose)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption).foregroundStyle(Theme.rose)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Theme.rose.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        if let pg = cycle.partnerPregnancy, pg.sharing, let due = pg.dueDate {
            partnerPregnancyView(due: due)
        } else if let p = cycle.partner, p.sharing, let phase = CyclePhase(rawValue: p.phase ?? "") {
            partnerCycleView(p, phase)
        } else {
            infoCard("When \(partnerName) turns on cycle sharing in her Us., you'll see her current phase here — plus what it means and simple, kind ways to support her.")
        }
        // No cycle-tracking controls here — a supporter never tracks or shares a
        // cycle of their own. Correcting the answer lives in Settings ▸ You.
    }

    @ViewBuilder
    private func partnerCycleView(_ p: PartnerCycle, _ phase: CyclePhase) -> some View {
        if let day = p.cycleDay {
            VStack(spacing: 10) {
                PhaseRing(phase: phase, cycleDay: day, cycleLength: estimatedLength(day, p.periodInDays))
                if let pid = p.periodInDays {
                    Text(pid <= 0 ? "Her period may start any day" : "Her next period in about \(pid) days")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
            }
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
    }

    @ViewBuilder
    private func partnerPregnancyView(due: Date) -> some View {
        let pg = PregnancyEngine.insights(dueDate: due)
        PregnancyRing(week: pg.week, daysToDue: pg.daysToDue)
            .padding(.top, 10).padding(.bottom, 4)
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("\(partnerName) is expecting", systemImage: "figure.child.circle.fill")
                    .font(.headline).foregroundStyle(Theme.rose)
                Text("Week \(pg.week) · the baby is about the size of \(pg.babySize).")
                    .font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Text(PregnancyEngine.trimesterAbout(pg.trimester))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to support her now").font(.headline)
                ForEach(PregnancyEngine.trimesterSupport(pg.trimester), id: \.self) { tip in
                    Label {
                        Text(tip).font(.subheadline)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.rose)
                    }
                }
            }
        }
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

// MARK: - Previews

#if DEBUG
@MainActor
private func cyclePreviewSession() -> Session {
    let s = Session()
    s.partner = User(id: "p", email: nil, displayName: "Claudia",
                     avatarPath: nil, birthday: nil, partnerPronoun: nil, createdAt: Date())
    return s
}

#Preview("Supporter — his view") {
    NavigationStack {
        CycleDetailView(cycle: .previewSupporter())
    }
    .environmentObject(cyclePreviewSession())
}

#Preview("Own cycle — her view") {
    NavigationStack {
        CycleDetailView(cycle: .previewSelf())
    }
    .environmentObject(cyclePreviewSession())
}

#Preview("Rings") {
    ScrollView {
        VStack(spacing: 24) {
            PhaseRing(phase: .menstrual, cycleDay: 3, cycleLength: 28)
            PhaseRing(phase: .ovulation, cycleDay: 14, cycleLength: 28)
            PhaseRing(phase: .luteal, cycleDay: 22, cycleLength: 28)
            PregnancyRing(week: 24, daysToDue: 112)
        }
        .padding(.vertical, 24)
    }
    .background(Theme.softBackground)
}
#endif
