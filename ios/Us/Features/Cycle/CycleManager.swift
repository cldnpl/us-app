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
            return "Phase, cycle day, and next-period countdown."
        case .cycleAndThoughts:
            return "Also the thoughts you write for the day."
        }
    }
}

/// Local persistence for the cycle feature's personal flags.
///
/// Everything in here belongs to *this iPhone*, not to the account signed in on
/// it: the Apple Health permission is granted to the app by the person holding
/// the phone, and iOS never revokes it on sign-out. So none of these keys are
/// cleared when the user signs out — otherwise the cycle would vanish and the
/// permission sheet, which iOS only ever shows once, could not be shown again.
enum CyclePrefs {
    private static let hasCycleKey = "userHasCycle"
    private static let pregnantKey = "isPregnant"
    private static let dueDateKey = "pregnancyDueDate"
    private static let healthConnectedKey = "healthKitConnected"
    private static let periodStartsKey = "cycleCachedPeriodStarts"

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

    /// True once the Apple Health permission sheet has been completed on this
    /// iPhone (or once we've successfully read cycle data, which proves access
    /// was granted in an older build). iOS shows that sheet exactly once, so
    /// this flag is what tells the UI to stop offering a "Connect" button that
    /// could no longer do anything.
    static var healthConnected: Bool {
        get { UserDefaults.standard.bool(forKey: healthConnectedKey) }
        set { UserDefaults.standard.set(newValue, forKey: healthConnectedKey) }
    }

    /// The period-start dates last read from Apple Health, kept on this iPhone
    /// so the cycle still renders when a live read isn't possible — at launch
    /// before Health unlocks, offline, and right after signing back in. The
    /// cache never leaves the device; the only thing uploaded is the summary
    /// the user explicitly chooses to share with her partner.
    static var cachedPeriodStarts: [Date] {
        get { (UserDefaults.standard.array(forKey: periodStartsKey) as? [Date]) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: periodStartsKey) }
    }
}

/// Owns the cycle state for the UI: your own insights (derived from Apple
/// Health), your partner's shared summary (read from the backend), your sharing
/// choice, and the free-text note for the day.
///
/// The Apple Health connection and the dates it gave us are cached on this
/// iPhone (see `CyclePrefs`) so the cycle survives a relaunch and a sign-out —
/// the Health permission belongs to the device, not to the account, and asking
/// for it a second time is impossible.
@MainActor
final class CycleManager: ObservableObject {
    static let shared = CycleManager()

    @Published private(set) var insights: CycleInsights?
    @Published private(set) var partner: PartnerCycle?
    @Published var todayNote: String = ""
    @Published var lastError: String?

    /// Whether Apple Health has been connected on this iPhone. Persisted, so it
    /// stays true across relaunches and sign-outs even before the first read of
    /// the session comes back.
    @Published private(set) var isHealthConnected: Bool = CyclePrefs.healthConnected

    init() {
        // Show the last known cycle immediately. HealthKit may not answer for a
        // while (or at all, if the device is still locked), and the account
        // being signed in has nothing to do with the Health data on this phone.
        insights = CycleEngine.insights(fromPeriodStarts: CyclePrefs.cachedPeriodStarts)
    }

    /// Whether *this user* has a menstrual cycle (set in onboarding). nil = not
    /// asked yet (existing users) → we offer the choice from the cycle screen.
    /// true → she tracks her own cycle; false → he sees his partner's + tips.
    ///
    /// The account is the source of truth; the local copy is a cache so the UI
    /// renders correctly before the first response and while offline.
    @Published var userHasCycle: Bool? = CyclePrefs.userHasCycle

    func setUserHasCycle(_ value: Bool) {
        CyclePrefs.userHasCycle = value
        userHasCycle = value
        Task { try? await APIClient.shared.updateCycleSettings(hasCycle: value) }
    }

    /// Reconciles the cycle settings with the account after login/refresh.
    ///
    /// The server wins when it has an answer. When it doesn't but this device
    /// does — a user upgrading from a build that only stored these locally —
    /// the local answer is pushed up so it isn't silently lost.
    func adoptServerSettings(from user: User) {
        if let serverHasCycle = user.hasCycle {
            if userHasCycle != serverHasCycle {
                CyclePrefs.userHasCycle = serverHasCycle
                userHasCycle = serverHasCycle
            }
        } else if let local = userHasCycle {
            Task { try? await APIClient.shared.updateCycleSettings(hasCycle: local) }
        }

        if let raw = user.cycleShareLevel, let serverLevel = CycleShareLevel(rawValue: raw) {
            // "off" is also the server's default for accounts that never set a
            // level, so a local non-off choice from an older build still wins
            // and gets pushed up rather than being reset to off.
            if serverLevel == .off, shareLevel != .off {
                Task { try? await APIClient.shared.updateCycleSettings(shareLevel: shareLevel.rawValue) }
            } else if serverLevel != shareLevel {
                UserDefaults.standard.set(serverLevel.rawValue, forKey: shareLevelKey)
                objectWillChange.send()
            }
        }
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
        #if DEBUG
        // Keep seeded state intact inside Xcode Previews (no live network).
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return }
        #endif
        await refreshPartner()
        partnerPregnancy = try? await APIClient.shared.partnerPregnancy()
        loadTodayNote()
        // People without a cycle have nothing to read from Apple Health.
        guard userHasCycle != false, HealthKitManager.shared.isAvailable else { return }
        await refreshInsights()
        if shareLevel != .off { await pushShare() }
    }

    /// Ask for Health permission, then load my cycle and publish my summary.
    ///
    /// The connection is remembered on this iPhone even if the read that follows
    /// comes back empty: iOS won't show the permission sheet twice, so a user
    /// whose tracking app hasn't synced yet must not be sent back to a "Connect"
    /// button that can no longer do anything.
    func connectHealth() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            markHealthConnected()
            await refreshInsights()
            if shareLevel != .off { await pushShare() }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Re-read Apple Health and update the cycle.
    ///
    /// A read that comes back empty — Health still locked, the tracking app
    /// (Flo, Clue, …) hasn't synced yet, access revoked in Settings — must never
    /// wipe what we already know. We keep the cached dates, and the ring keeps
    /// advancing from them until Health has something newer to say.
    func refreshInsights() async {
        do {
            let starts = try await HealthKitManager.shared.periodStartDates()
            guard !starts.isEmpty else {
                if insights == nil {
                    insights = CycleEngine.insights(fromPeriodStarts: CyclePrefs.cachedPeriodStarts)
                }
                return
            }
            CyclePrefs.cachedPeriodStarts = starts
            insights = CycleEngine.insights(fromPeriodStarts: starts)
            // Reading real samples proves access was granted — this also heals
            // users who connected in a build that didn't record the flag.
            markHealthConnected()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func markHealthConnected() {
        guard !isHealthConnected else { return }
        CyclePrefs.healthConnected = true
        isHealthConnected = true
    }

    /// Sign-out cleanup. Only the partner's shared data belongs to the account
    /// that just signed out; the Health connection, the cached cycle and the
    /// "do you have a cycle?" answer belong to this iPhone and are deliberately
    /// kept, so signing back in never means setting the cycle up again.
    func forgetPartnerData() {
        partner = nil
        partnerPregnancy = nil
    }

    func refreshPartner() async {
        // The partner's phase can only come from the backend — his device has no
        // access to her Apple Health. Real shared data only; no fake fallback.
        partner = try? await APIClient.shared.partnerCycle()
    }

    /// Change the sharing level and immediately push (or clear) my summary.
    /// The level itself is stored on the account so it survives a reinstall.
    func setShareLevel(_ level: CycleShareLevel) async {
        UserDefaults.standard.set(level.rawValue, forKey: shareLevelKey)
        objectWillChange.send()
        _ = try? await APIClient.shared.updateCycleSettings(shareLevel: level.rawValue)
        await pushShare()
    }

    // MARK: Today's note

    private var noteKey: String {
        let f = DateFormatter()
        // Fixed format for a storage key, so it must not follow the user's
        // locale: a Thai or Persian locale would render a different calendar's
        // year here and silently point at a different note every day.
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
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

#if DEBUG
extension CycleManager {
    /// A fresh manager for a supporter (male) whose partner is sharing.
    static func previewSupporter() -> CycleManager {
        let m = CycleManager()
        m.userHasCycle = false
        m.partner = PartnerCycle(
            sharing: true, phase: CyclePhase.ovulation.rawValue, cycleDay: 14,
            periodInDays: 14, note: "I miss youuu 💛",
            partnerName: "Claudia", updatedAt: nil)
        return m
    }

    /// A fresh manager for someone tracking their own cycle.
    static func previewSelf() -> CycleManager {
        let m = CycleManager()
        m.userHasCycle = true
        m.insights = CycleEngine.insights(
            fromPeriodStarts: [Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()])
        return m
    }
}
#endif
