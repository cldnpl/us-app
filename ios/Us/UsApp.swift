import SwiftUI

@main
struct UsApp: App {
    @StateObject private var session = Session()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task { await session.bootstrap() }
                .tint(Theme.coral)
        }
    }
}
