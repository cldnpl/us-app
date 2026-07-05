import Foundation
import SwiftUI

/// How much of your cycle you share with your partner. Off by default.
enum CycleShareLevel: String, CaseIterable {
    case off, mood, full

    var title: String {
        switch self {
        case .off:  return "Not sharing"
        case .mood: return "Just how I feel"
        case .full: return "Feelings + days"
        }
    }

    func explanation(partnerName: String) -> String {
        switch self {
        case .off:  return "\(partnerName) sees nothing about your cycle."
        case .mood: return "\(partnerName) sees only your current phase — a gentle heads-up, no numbers."
        case .full: return "\(partnerName) also sees your cycle day and a rough countdown to your next period."
        }
    }
}

/// Local persistence for the cycle feature's personal flags.
enum CyclePrefs {
    private static let hasCycleKey = "userHasCycle"

    /// nil until the user answers (in onboarding or from the cycle screen).
    static var userHasCycle: Bool? {
        get { UserDefaults.standard.object(forKey: hasCycleKey) as? Bool }
        set {
            if let newValue { UserDefaults.standard.set(newValue, forKey: hasCycleKey) }
            else { UserDefaults.standard.removeObject(forKey: hasCycleKey) }
        }
    }
}

/// Owns the cycle state for the UI: your own insights (read from Apple Health),
/// your partner's shared summary (read from the backend), and your sharing choice.
/// The share level is the only cycle setting persisted locally; health data is
/// never cached by us.
@MainActor
final class CycleManager: ObservableObject {
    static let shared = CycleManager()

    @Published private(set) var insights: CycleInsights?
    @Published private(set) var partner: PartnerCycle?
    @Published var lastError: String?

    /// Whether *this user* has a menstrual cycle (set in onboarding). nil = not
    /// asked yet (existing users) → we offer the choice from the cycle screen.
    /// true → she tracks her own cycle; false → he sees his partner's + tips.
    @Published var userHasCycle: Bool? = CyclePrefs.userHasCycle

    func setUserHasCycle(_ value: Bool) {
        CyclePrefs.userHasCycle = value
        userHasCycle = value
    }

    private let shareLevelKey = "cycleShareLevel"

    var shareLevel: CycleShareLevel {
        CycleShareLevel(rawValue: UserDefaults.standard.string(forKey: shareLevelKey) ?? "") ?? .off
    }

    /// Called when a screen appears: refresh the partner card, and (if Health is
    /// available) my own cycle, keeping my shared summary current if sharing is on.
    func refreshOnAppear() async {
        await refreshPartner()
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
        partner = try? await APIClient.shared.partnerCycle()
    }

    /// Change the sharing level and immediately push (or clear) my summary.
    func setShareLevel(_ level: CycleShareLevel) async {
        UserDefaults.standard.set(level.rawValue, forKey: shareLevelKey)
        objectWillChange.send()
        await pushShare()
    }

    /// Upload the summary the current level allows, or clear it when off.
    private func pushShare() async {
        guard shareLevel != .off, let insights else {
            try? await APIClient.shared.stopSharingCycle()
            return
        }
        let shareDays = shareLevel == .full
        try? await APIClient.shared.putCycle(
            phase: insights.phase.rawValue,
            cycleDay: shareDays ? insights.cycleDay : nil,
            periodInDays: shareDays ? insights.daysUntilNextPeriod : nil)
    }
}
