import UIKit
import UserNotifications

/// Requests notification permission, obtains the APNs device token, and
/// registers it with the backend so the partner's "Miss You" can reach this device.
@MainActor
final class PushManager {
    static let shared = PushManager()
    private var deviceTokenHex: String?

    /// Call once the user is signed in. Registers the device when notifications
    /// are already allowed, and deliberately does NOT prompt.
    ///
    /// iOS shows the permission sheet exactly once per install, ever. Asking the
    /// instant someone signs in spends that one chance before they've seen a
    /// quiz, the journal, or even their partner — so the ask lives in
    /// `NotificationsPrimerView`, after pairing, where it can say what it's for.
    func onAuthenticated() async {
        await registerIfAllowed()
    }

    /// Presents the iOS permission sheet and registers if it's granted.
    /// Returns whether notifications ended up allowed.
    @discardableResult
    func requestPermission() async -> Bool {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return await registerIfAllowed()
    }

    /// Whether iOS has never asked — the only state in which asking can work.
    var canStillAsk: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings()
                .authorizationStatus == .notDetermined
        }
    }

    @discardableResult
    private func registerIfAllowed() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return false }
        UIApplication.shared.registerForRemoteNotifications()
        await sendTokenIfPossible()
        return true
    }

    /// Called by the AppDelegate when APNs returns a device token.
    func handleDeviceToken(_ hex: String) async {
        deviceTokenHex = hex
        await sendTokenIfPossible()
    }

    private func sendTokenIfPossible() async {
        guard let token = deviceTokenHex, TokenStore.accessToken != nil else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        try? await APIClient.shared.registerDevice(apnsToken: token, environment: environment)
    }

    func reset() { deviceTokenHex = nil }
}
