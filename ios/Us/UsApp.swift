import SwiftUI

@main
struct UsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = Session()
    @StateObject private var premium = PremiumStore.shared
    @ObservedObject private var languages = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(premium)
                .task { await session.bootstrap() }
                .tint(Theme.rose)
                // Rebuild the whole tree when the language changes so every
                // already-rendered string is re-read from the new bundle, and
                // mirror the layout for right-to-left languages.
                .environment(\.locale, languages.locale)
                .environment(\.layoutDirection, languages.layoutDirection)
                .id(languages.current.code)
        }
        .onChange(of: scenePhase) { phase in
            // Coming back to the app is when we re-read the profile and couple,
            // so a name or email your partner changed on their device shows up
            // here without a relaunch.
            guard phase == .active else { return }
            Task { await session.refreshFromServer() }
        }
    }
}
