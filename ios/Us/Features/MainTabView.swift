import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: Session
    @State private var showSetup = false
    @State private var showNotificationsPrimer = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(loc: "Home", systemImage: "house.fill") }

            TogetherView()
                .tabItem { Label(loc: "Games", systemImage: "sparkles") }

            JournalView()
                .tabItem { Label(loc: "Journal", systemImage: "book.closed.fill") }

            SettingsView()
                .tabItem { Label(loc: "Settings", systemImage: "gearshape.fill") }
        }
        // First run after pairing: pick partner pronoun + grant location.
        .fullScreenCover(isPresented: $showSetup) {
            SetupFlowView(isPresented: $showSetup)
        }
        // Then, and only then, ask about notifications — with a partner on the
        // other end, the ask finally has something to point at.
        .fullScreenCover(isPresented: $showNotificationsPrimer) {
            NotificationsPrimerView(isPresented: $showNotificationsPrimer)
        }
        .onAppear {
            showSetup = SetupFlowView.isNeeded(session: session)
            if !showSetup { Task { await offerNotificationsIfNeeded() } }
        }
        .onChange(of: showSetup) { presenting in
            // Two full-screen covers can't overlap: wait for setup to close.
            if !presenting { Task { await offerNotificationsIfNeeded() } }
        }
    }

    private func offerNotificationsIfNeeded() async {
        if await NotificationsPrimerView.isNeeded() { showNotificationsPrimer = true }
    }
}

/// Placeholder for feature tabs shipping in later phases.
struct ComingSoonView: View {
    let title: String
    let symbol: String
    let blurb: String

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                VStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.coral)
                    Text(verbatim: title).font(.title.bold())
                    Text(verbatim: blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(loc: "Coming soon")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.coral.opacity(0.15), in: Capsule())
                        .foregroundStyle(Theme.coral)
                }
                .padding(32)
            }
            .navigationTitle(title)
        }
    }
}
