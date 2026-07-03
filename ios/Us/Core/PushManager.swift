import UIKit
import UserNotifications

/// Requests notification permission, obtains the APNs device token, and
/// registers it with the backend so the partner's "Miss You" can reach this device.
@MainActor
final class PushManager {
    static let shared = PushManager()
    private var deviceTokenHex: String?

    /// Call once the user is signed in: prompt for permission and register.
    func onAuthenticated() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        UIApplication.shared.registerForRemoteNotifications()
        await sendTokenIfPossible()
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
