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
    ///
    /// The login must survive app restarts: once signed in, the ONLY things that
    /// send the user back to the sign-in screen are an explicit sign-out or the
    /// backend definitively rejecting the refresh token (a real 401). A network
    /// blip, a server error, or a slow launch must NOT throw the session away.
    func bootstrap() async {
        // The iOS Keychain survives app uninstall, but UserDefaults does not. On
        // the first launch after a fresh (re)install, wipe any stale tokens so the
        // user starts at sign-in — not stranded mid-onboarding with a ghost
        // session left behind in the Keychain.
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            // Only a true fresh install has an empty UserDefaults; an existing
            // install updating to this build still carries its prior keys, so we
            // must not sign those users out just for adding this flag.
            let hadPriorUse = UserDefaults.standard.bool(forKey: "didCompletePersonalOnboarding")
                || UserDefaults.standard.bool(forKey: "testPaired")
                || UserDefaults.standard.object(forKey: "userHasCycle") != nil
            if !hadPriorUse {
                TokenStore.clear()
                SessionCache.clear()
            }
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
        guard TokenStore.accessToken != nil || TokenStore.refreshToken != nil else {
            state = .signedOut
            return
        }
        // Make sure the widget extension has fresh tokens to send "I miss you".
        TokenStore.syncToSharedStore()
        do {
            user = try await APIClient.shared.me()
            syncPronounFromServer()
            syncCycleSettingsFromServer()
            try await refreshCouple()
            await PushManager.shared.onAuthenticated()
        } catch APIClientError.unauthorized {
            // Refresh token was rejected: the only unrecoverable case, and the
            // only place bootstrap is allowed to drop the session.
            TokenStore.clear()
            SessionCache.clear()
            state = .signedOut
        } catch {
            // Transient failure (offline, server error, timeout). The tokens are
            // still valid, so keep the user logged in and restore the last known
            // session from cache; live data refreshes on next use.
            restoreCachedSession()
        }
    }

    /// Loads the couple from the backend. Non-throwing: used after interactive
    /// actions (login, pairing, saving the start date) where we simply route by
    /// local progress if the request fails. Bootstrap calls `refreshCouple()`
    /// directly so it can tell a transient failure apart from "not paired".
    func loadCouple() async {
        do {
            try await refreshCouple()
        } catch {
            if restoreTestPairingIfNeeded() { return }
            state = personalOnboardingDone ? .needsPairing : .needsPersonalOnboarding
        }
    }

    /// Fetches the couple and updates state. On success either enters `.ready`
    /// (paired — cached so the app can reopen logged-in even offline) or routes
    /// to the correct onboarding/pairing step (genuinely not paired). Throws on
    /// a network/server failure so callers can fall back to the cache.
    private func refreshCouple() async throws {
        let resp = try await APIClient.shared.getCouple()
        if resp.paired, let couple = resp.couple {
            self.couple = couple
            self.partner = resp.partner
            UserDefaults.standard.set(false, forKey: "testPaired") // a real couple wins
            if let user { SessionCache.save(user: user, partner: resp.partner, couple: couple) }
            state = .ready
            updateWidget()
            return
        }
        // Reached the server and we're genuinely not paired — drop stale cache.
        SessionCache.clear()
        if restoreTestPairingIfNeeded() { return }
        state = personalOnboardingDone ? .needsPairing : .needsPersonalOnboarding
    }

    /// Restores the persisted "0000" test pairing (DEBUG/demo) if it was used,
    /// so relaunch/login goes straight to Home. Returns true if it took over.
    private func restoreTestPairingIfNeeded() -> Bool {
        guard SharedConfig.demoMode, UserDefaults.standard.bool(forKey: "testPaired") else { return false }
        enterTestPairing()
        return true
    }

    /// Restores the last-known signed-in UI from local cache after a transient
    /// launch failure, so a valid login survives being offline. Prefers any
    /// fresh data already loaded this launch and fills the gaps from cache.
    private func restoreCachedSession() {
        if let cached = SessionCache.load() {
            if user == nil { user = cached.user }
            partner = partner ?? cached.partner
            couple = couple ?? cached.couple
            state = .ready
            updateWidget()
            return
        }
        if restoreTestPairingIfNeeded() { return }
        // Logged in (token present) but nothing cached yet: route by local
        // progress rather than forcing the user to sign in again.
        state = personalOnboardingDone ? .needsPairing : .needsPersonalOnboarding
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
            applyUpdatedUser(updated)
        }
    }

    /// Adopts a fresh copy of the signed-in user: republishes the cache and the
    /// widget so a renamed user doesn't linger anywhere.
    func applyUpdatedUser(_ updated: User) {
        user = updated
        CycleManager.shared.adoptServerSettings(from: updated)
        if let couple { SessionCache.save(user: updated, partner: partner, couple: couple) }
        updateWidget()
    }

    /// Re-reads the profile and couple from the backend. Called when the app
    /// comes to the foreground so a change made on the partner's device (their
    /// name, their email) shows up here without needing a relaunch.
    ///
    /// Deliberately silent: a failure leaves the current state untouched rather
    /// than disturbing a working session.
    func refreshFromServer() async {
        guard state == .ready else { return }
        if let fresh = try? await APIClient.shared.me() {
            user = fresh
            CycleManager.shared.adoptServerSettings(from: fresh)
        }
        try? await refreshCouple()
    }

    func handleAuth(_ resp: AuthResponse) async {
        TokenStore.accessToken = resp.accessToken
        TokenStore.refreshToken = resp.refreshToken
        user = resp.user
        syncPronounFromServer()
        syncCycleSettingsFromServer()
        await loadCouple()
        await PushManager.shared.onAuthenticated()
    }

    func signOut() async {
        try? await APIClient.shared.logout()
        TokenStore.clear()
        SessionCache.clear()
        UserDefaults.standard.set(false, forKey: "testPaired")
        UserDefaults.standard.removeObject(forKey: "testStartDate")
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
        Task { try? await APIClient.shared.updatePartnerPronoun(pronoun.rawValue) }
    }

    /// Reconcile the partner pronoun with the server after login, so it survives
    /// re-login and reinstalls without asking for it again.
    private func syncPronounFromServer() {
        if let raw = user?.partnerPronoun, let p = PartnerPronoun(rawValue: raw) {
            // Server knows it → mirror into local prefs (+ widget App Group).
            if PartnerPrefs.pronoun != p { PartnerPrefs.pronoun = p }
        } else if let local = PartnerPrefs.pronoun {
            // Existing user: server doesn't have it yet, but we do → back it up.
            Task { try? await APIClient.shared.updatePartnerPronoun(local.rawValue) }
        }
    }

    /// Reconcile the cycle settings with the server after login. The server is
    /// authoritative once it has an answer; a local-only answer from a build
    /// that predates server storage is pushed up so it isn't lost.
    private func syncCycleSettingsFromServer() {
        guard let user else { return }
        CycleManager.shared.adoptServerSettings(from: user)
    }

    /// Saves the couple's start date and refreshes the couple + widget.
    func saveStartDate(_ date: Date) async {
        if SharedConfig.demoMode, UserDefaults.standard.bool(forKey: "testPaired") {
            // Test pairing: persist locally so it survives relaunch AND the
            // widget's day count matches what's shown in the app.
            UserDefaults.standard.set(date, forKey: "testStartDate")
            couple = Couple(id: couple?.id ?? "test-couple", startDate: date,
                            status: "active", createdAt: couple?.createdAt ?? Date())
            updateWidget()
            return
        }
        let iso = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        _ = try? await APIClient.shared.setStartDate(iso)
        await loadCouple()
    }

    /// TEST ONLY (SharedConfig.demoMode): opens the app without a real partner
    /// (pairing code "0000"). Backend features are empty/error, but the UI is
    /// testable. The choice persists (`testPaired`) so relaunch goes to Home.
    func enterTestPairing() {
        UserDefaults.standard.set(true, forKey: "testPaired")
        let start = (UserDefaults.standard.object(forKey: "testStartDate") as? Date)
            ?? Calendar.current.date(byAdding: .day, value: -100, to: Date())
        partner = User(id: "test-partner", email: nil, displayName: "Partner",
                       avatarPath: nil, birthday: nil, partnerPronoun: nil, createdAt: Date())
        couple = Couple(id: "test-couple", startDate: start, status: "active", createdAt: Date())
        state = .ready
        updateWidget()
    }

    /// Names written into the widget snapshot. In DEBUG the partner falls back
    /// to "Alex" (and self to "Claudia") so the test widget matches the app.
    private var snapshotMyName: String {
        user?.displayName ?? (SharedConfig.demoMode ? "Claudia" : "")
    }
    private var snapshotPartnerName: String {
        let real = partner?.displayName
        if SharedConfig.demoMode, real == nil || real?.isEmpty == true || real == "Partner" {
            return "Alex"
        }
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

/// Locally cached snapshot of the signed-in session (profile + couple) so the
/// app can reopen straight into the logged-in UI — even before the network
/// responds, or fully offline. The Keychain tokens remain the source of truth
/// for *authentication*; this only remembers the *couple/profile* we last saw,
/// so a transient launch-time API failure never forces the user back to sign-in.
enum SessionCache {
    private static let key = "cachedSession.v1"

    struct Snapshot: Codable {
        let user: User
        let partner: User?
        let couple: Couple
    }

    static func save(user: User, partner: User?, couple: Couple) {
        let snapshot = Snapshot(user: user, partner: partner, couple: couple)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Snapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
