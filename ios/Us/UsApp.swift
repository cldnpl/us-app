import SwiftUI

@main
struct UsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task { await session.bootstrap() }
                .tint(Theme.rose)
        }
    }
}
