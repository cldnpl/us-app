import Foundation
import SwiftUI
import WidgetKit

/// Global app state: authentication, current user, and couple.
@MainActor
final class Session: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case needsPersonalOnboarding
        case needsPairing
        case ready
    }

    @Published var state: State = .loading
    @Published var user: User?
    @Published var partner: User?
    @Published var couple: Couple?

    /// Called on launch to restore an existing session.
    func bootstrap() async {
        guard TokenStore.accessToken != nil else {
            state = .signedOut
            return
        }
        // Make sure the widget extension has fresh tokens to send "I miss you".
        TokenStore.syncToSharedStore()
        do {
            user = try await APIClient.shared.me()
            await loadCouple()
            await PushManager.shared.onAuthenticated()
        } catch {
            TokenStore.clear()
            state = .signedOut
        }
    }

    func loadCouple() async {
        do {
            let resp = try await APIClient.shared.getCouple()
            if resp.paired, let couple = resp.couple {
                self.couple = couple
                self.partner = resp.partner
                state = .ready
                updateWidget()
            } else {
                state = personalOnboardingDone ? .needsPairing : .needsPersonalOnboarding
            }
        } catch {
            state = personalOnboardingDone ? .needsPairing : .needsPersonalOnboarding
        }
    }

    /// Whether the person has completed the "about you" onboarding (name +
    /// location), which runs once after sign-in and before pairing.
    var personalOnboardingDone: Bool {
        UserDefaults.standard.bool(forKey: "didCompletePersonalOnboarding")
    }

    /// Marks personal onboarding complete and advances to pairing.
    func completePersonalOnboarding() {
        UserDefaults.standard.set(true, forKey: "didCompletePersonalOnboarding")
        state = .needsPairing
    }

    /// Saves the user's chosen display name to the backend.
    func updateName(_ displayName: String) async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let updated = try? await APIClient.shared.updateProfile(displayName: trimmed) {
            user = updated
        }
    }

    func handleAuth(_ resp: AuthResponse) async {
        TokenStore.accessToken = resp.accessToken
        TokenStore.refreshToken = resp.refreshToken
        user = resp.user
        await loadCouple()
        await PushManager.shared.onAuthenticated()
    }

    func signOut() async {
        try? await APIClient.shared.logout()
        TokenStore.clear()
        user = nil
        partner = nil
        couple = nil
        state = .signedOut
    }

    /// Days since the relationship start date, if set.
    var daysTogether: Int? {
        guard let start = couple?.startDate else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: Date()).day
    }

    /// The object pronoun to use in copy ("thinking of her / him / them").
    var partnerPronounObject: String { PartnerPrefs.thinkingOfObject }

    /// Whether the partner pronoun has been chosen (drives first-run setup).
    var hasChosenPronoun: Bool { PartnerPrefs.pronoun != nil }

    /// Persist the chosen partner pronoun (shared with the widget/App Group).
    func setPartnerPronoun(_ pronoun: PartnerPronoun) {
        PartnerPrefs.pronoun = pronoun
        objectWillChange.send()
    }

    /// Saves the couple's start date and refreshes the couple + widget.
    func saveStartDate(_ date: Date) async {
        let iso = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        _ = try? await APIClient.shared.setStartDate(iso)
        await loadCouple()
    }

    #if DEBUG
    /// TEST ONLY: opens the app without a real partner (pairing code "0000").
    /// Backend-backed features will be empty/error, but the UI is fully testable.
    /// Remove this and the "0000" handling in PairingView before shipping.
    func enterTestPairing() {
        partner = User(id: "test-partner", email: nil, displayName: "Partner",
                       avatarPath: nil, birthday: nil, createdAt: Date())
        couple = Couple(id: "test-couple",
                        startDate: Calendar.current.date(byAdding: .day, value: -100, to: Date()),
                        status: "active", createdAt: Date())
        PartnerPrefs.partnerName = partner?.displayName
        state = .ready
        updateWidget()
    }
    #endif

    /// Names written into the widget snapshot. In DEBUG the partner falls back
    /// to "Elbek" (and self to "Claudia") so the test widget matches the app.
    private var snapshotMyName: String {
        #if DEBUG
        return user?.displayName ?? "Claudia"
        #else
        return user?.displayName ?? ""
        #endif
    }
    private var snapshotPartnerName: String {
        let real = partner?.displayName
        #if DEBUG
        if real == nil || real?.isEmpty == true || real == "Partner" { return "Elbek" }
        #endif
        return real ?? ""
    }

    /// Publish the couple snapshot to the App Group and refresh the widget.
    private func updateWidget() {
        PartnerPrefs.partnerName = snapshotPartnerName
        let existing = WidgetStore.load()
        WidgetStore.save(WidgetSnapshot(
            partnerName: snapshotPartnerName,
            daysTogether: daysTogether,
            updatedAt: Date(),
            myName: snapshotMyName,
            distanceKm: existing?.distanceKm
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Publish the latest partner distance (km) to the widget. Called from Home
    /// whenever a fresh distance is computed; pass nil to clear it.
    func publishDistance(_ km: Double?) {
        let existing = WidgetStore.load()
        WidgetStore.save(WidgetSnapshot(
            partnerName: snapshotPartnerName.isEmpty ? (existing?.partnerName ?? "") : snapshotPartnerName,
            daysTogether: daysTogether ?? existing?.daysTogether,
            updatedAt: Date(),
            myName: snapshotMyName.isEmpty ? existing?.myName : snapshotMyName,
            distanceKm: km
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
