import SwiftUI

@main
struct UsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = Session()
    @StateObject private var premium = PremiumStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(premium)
                .task { await session.bootstrap() }
                .tint(Theme.rose)
        }
    }
}
