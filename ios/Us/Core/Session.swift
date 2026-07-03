import Foundation
import SwiftUI
import WidgetKit

/// Global app state: authentication, current user, and couple.
@MainActor
final class Session: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
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
                state = .needsPairing
            }
        } catch {
            state = .needsPairing
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

    /// Publish the couple snapshot to the App Group and refresh the widget.
    private func updateWidget() {
        WidgetStore.save(WidgetSnapshot(
            partnerName: partner?.displayName ?? "",
            daysTogether: daysTogether,
            updatedAt: Date()
        ))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
