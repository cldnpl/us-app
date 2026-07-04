import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var session: Session
    @State private var showSetup = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            TogetherView()
                .tabItem { Label("Activities", systemImage: "sparkles") }

            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        // First run after pairing: pick partner pronoun + grant location.
        .fullScreenCover(isPresented: $showSetup) {
            SetupFlowView(isPresented: $showSetup)
        }
        .onAppear { showSetup = SetupFlowView.isNeeded(session: session) }
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
                    Text(title).font(.title.bold())
                    Text(blurb)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Coming soon")
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
