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
            case .needsPersonalOnboarding:
                PersonalOnboardingView()
            case .needsPairing:
                PairingView()
            case .ready:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: session.state)
        // iOS 16 widget fallback: the widget opens the app via usapp://missyou;
        // send the nudge and give a little haptic. (On iOS 17+ the widget sends
        // silently without launching, so this path isn't hit.)
        .onOpenURL { url in
            guard url == SharedConfig.missYouURL else { return }
            Task {
                if (try? await APIClient.shared.sendMissYou()) != nil { Haptics.tap(.heavy) }
            }
        }
    }
}
