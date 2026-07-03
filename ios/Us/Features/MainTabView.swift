import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            GalleryView()
                .tabItem { Label("Gallery", systemImage: "photo.on.rectangle") }

            ComingSoonView(title: "Together", symbol: "scribble.variable",
                           blurb: "Draw together, play games, leave notes.")
                .tabItem { Label("Together", systemImage: "gamecontroller") }

            ComingSoonView(title: "Moments", symbol: "calendar.badge.clock",
                           blurb: "Anniversaries, reunions & your memory timeline.")
                .tabItem { Label("Moments", systemImage: "calendar") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
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
