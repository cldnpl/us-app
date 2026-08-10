import UIKit
import UserNotifications
import WidgetKit

/// Bridges UIKit push callbacks into the SwiftUI app.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Make sure the widget/extension token mirror is current even on a
        // background launch (no UI, so `Session.bootstrap()` may never run).
        TokenStore.syncToSharedStore()
        // Starting the manager here matters for background relaunches: iOS wakes
        // the app for a significant location change and only delivers it once a
        // CLLocationManager with a delegate exists.
        _ = LocationManager.shared
        return true
    }

    /// Silent push: the partner moved (or their profile changed). Refresh the
    /// distance and the widget without the user opening anything.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let km = await DistanceSync.refresh()
        WidgetCenter.shared.reloadAllTimelines()
        return km == nil ? .noData : .newData
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await PushManager.shared.handleDeviceToken(hex) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NSLog("Push registration failed: \(error.localizedDescription)")
    }

    /// Show the banner + play the sound even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
