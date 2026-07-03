import SwiftUI

/// Routes between the major app states based on auth + pairing.
struct RootView: View {
    @EnvironmentObject var session: Session

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                ZStack {
                    Theme.softBackground.ignoresSafeArea()
                    ProgressView().controlSize(.large)
                }
            case .signedOut:
                WelcomeView()
            case .needsPairing:
                PairingView()
            case .ready:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: session.state)
    }
}
