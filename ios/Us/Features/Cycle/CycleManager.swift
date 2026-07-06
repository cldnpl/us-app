import Foundation
import SwiftUI

/// How much of your cycle you share with your partner. Off by default.
enum CycleShareLevel: String, CaseIterable {
    case off, cycle, cycleAndThoughts

    var title: String {
        switch self {
        case .off:             return "Not sharing"
        case .cycle:           return "Cycle only"
        case .cycleAndThoughts: return "Cycle + thoughts"
        }
    }

    func explanation(partnerName: String) -> String {
        switch self {
        case .off:
            return "\(partnerName) sees nothing about your cycle."
        case .cycle:
            return "\(partnerName) sees your phase, cycle day, and a rough countdown to your next period."
        case .cycleAndThoughts:
            return "\(partnerName) also sees the thoughts you write for the day."
        }
    }
}

/// Local persistence for the cycle feature's personal flags.
enum CyclePrefs {
    private static let hasCycleKey = "userHasCycle"
    private static let pregnantKey = "isPregnant"
    private static let dueDateKey = "pregnancyDueDate"

    /// nil until the user answers (in onboarding or from the cycle screen).
    static var userHasCycle: Bool? {
        get { UserDefaults.standard.object(forKey: hasCycleKey) as? Bool }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: hasCycleKey) }
            else { UserDefaults.standard.removeObject(forKey: hasCycleKey) }
        }
    }

    static var isPregnant: Bool {
        get { UserDefaults.standard.bool(forKey: pregnantKey) }
        set { UserDefaults.standard.set(newValue, forKey: pregnantKey) }
    }

    static var dueDate: Date? {
        get { UserDefaults.standard.object(forKey: dueDateKey) as? Date }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: dueDateKey) }
            else { UserDefaults.standard.removeObject(forKey: dueDateKey) }
        }
    }
}

/// Owns the cycle state for the UI: your own insights (read from Apple Health),
/// your partner's shared summary (read from the backend), your sharing choice,
/// and the free-text note for the day. Only the sharing level, the flag, and the
/// note are persisted locally; health data is never cached by us.
@MainActor
final class CycleManager: ObservableObject {
    static let shared = CycleManager()

    @Published private(set) var insights: CycleInsights?
    @Published private(set) var partner: PartnerCycle?
    @Published var todayNote: String = ""
    @Published var lastError: String?

    /// Whether *this user* has a menstrual cycle (set in onboarding). nil = not
    /// asked yet (existing users) → we offer the choice from the cycle screen.
    /// true → she tracks her own cycle; false → he sees his partner's + tips.
    @Published var userHasCycle: Bool? = CyclePrefs.userHasCycle

    func setUserHasCycle(_ value: Bool) {
        CyclePrefs.userHasCycle = value
        userHasCycle = value
    }

    // MARK: Pregnancy

    @Published var isPregnant: Bool = CyclePrefs.isPregnant
    @Published var dueDate: Date? = CyclePrefs.dueDate
    @Published var partnerPregnancy: PartnerPregnancy?

    var pregnancyInsights: PregnancyInsights? {
        guard isPregnant, let dueDate else { return nil }
        return PregnancyEngine.insights(dueDate: dueDate)
    }

    /// Enter pregnancy mode with a due date and share it with the partner.
    func startPregnancy(dueDate: Date) async {
        CyclePrefs.isPregnant = true
        CyclePrefs.dueDate = dueDate
        isPregnant = true
        self.dueDate = dueDate
        try? await APIClient.shared.putPregnancy(dueDate: dueDate)
    }

    /// Leave pregnancy mode and stop sharing the due date.
    func endPregnancy() async {
        CyclePrefs.isPregnant = false
        CyclePrefs.dueDate = nil
        isPregnant = false
        dueDate = nil
        try? await APIClient.shared.stopSharingPregnancy()
    }

    private let shareLevelKey = "cycleShareLevel"

    var shareLevel: CycleShareLevel {
        switch UserDefaults.standard.string(forKey: shareLevelKey) {
        // Legacy values ("mood"/"full") map to sharing the cycle, never thoughts.
        case CycleShareLevel.cycle.rawValue, "mood", "full": return .cycle
        case CycleShareLevel.cycleAndThoughts.rawValue: return .cycleAndThoughts
        default: return .off
        }
    }

    /// Called when a screen appears: refresh the partner card, load today's note,
    /// and (if Health is available) my own cycle, keeping my summary current.
    func refreshOnAppear() async {
        await refreshPartner()
        partnerPregnancy = try? await APIClient.shared.partnerPregnancy()
        loadTodayNote()
        // People without a cycle have nothing to read from Apple Health.
        guard userHasCycle != false, HealthKitManager.shared.isAvailable else { return }
        await refreshInsights()
        if shareLevel != .off { await pushShare() }
    }

    /// Ask for Health permission, then load my cycle and publish my summary.
    func connectHealth() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            await refreshInsights()
            if shareLevel != .off { await pushShare() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshInsights() async {
        do {
            let starts = try await HealthKitManager.shared.periodStartDates()
            insights = CycleEngine.insights(fromPeriodStarts: starts)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshPartner() async {
        // The partner's phase can only come from the backend — his device has no
        // access to her Apple Health. Real shared data only; no fake fallback.
        partner = try? await APIClient.shared.partnerCycle()
    }

    /// Change the sharing level and immediately push (or clear) my summary.
    func setShareLevel(_ level: CycleShareLevel) async {
        UserDefaults.standard.set(level.rawValue, forKey: shareLevelKey)
        objectWillChange.send()
        await pushShare()
    }

    // MARK: Today's note

    private var noteKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "cycleNote." + f.string(from: Date())
    }

    func loadTodayNote() {
        todayNote = UserDefaults.standard.string(forKey: noteKey) ?? ""
    }

    /// Persist the day's note locally (no network).
    func saveNote(_ text: String) {
        todayNote = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { UserDefaults.standard.removeObject(forKey: noteKey) }
        else { UserDefaults.standard.set(text, forKey: noteKey) }
    }

    /// Push the latest note to the partner if sharing includes thoughts.
    func syncNoteIfSharing() async {
        if shareLevel == .cycleAndThoughts { await pushShare() }
    }

    /// Upload the summary the current level allows, or clear it when off.
    private func pushShare() async {
        guard shareLevel != .off, let insights else {
            try? await APIClient.shared.stopSharingCycle()
            return
        }
        let trimmedNote = todayNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = shareLevel == .cycleAndThoughts && !trimmedNote.isEmpty ? trimmedNote : nil
        try? await APIClient.shared.putCycle(
            phase: insights.phase.rawValue,
            cycleDay: insights.cycleDay,
            periodInDays: insights.daysUntilNextPeriod,
            note: note)
    }
}
