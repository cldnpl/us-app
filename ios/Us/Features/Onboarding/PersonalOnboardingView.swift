import SwiftUI

/// "About you" onboarding, shown once right after sign-in and before pairing:
/// 1. confirm your name,
/// 2. choose whether to turn on location (for distance features & widgets).
///
/// Apple HIG: we explain *why* before triggering the system location prompt.
struct PersonalOnboardingView: View {
    @EnvironmentObject var session: Session
    @StateObject private var location = LocationManager.shared

    @State private var step: Step = .name
    @State private var name = ""
    @State private var saving = false

    enum Step { case name, location }

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()
            switch step {
            case .name: nameStep
            case .location: locationStep
            }
        }
        .onAppear { if name.isEmpty { name = session.user?.displayName ?? "" } }
    }

    // MARK: - Step 1 · Name

    private var nameStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "person.fill")
                .font(.system(size: 52)).foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("What's your name?")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("This is how your partner will see you in Us.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }

            TextField("Your name", text: $name)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .tint(.white)
                .padding(16)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            Button { Task { await advanceFromName() } } label: {
                if saving { ProgressView().tint(.white) } else { Text("Continue") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmedName.isEmpty || saving)
            .opacity(trimmedName.isEmpty ? 0.6 : 1)
        }
        .padding(28)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func advanceFromName() async {
        saving = true
        await session.updateName(trimmedName)
        saving = false
        withAnimation { step = .location }
    }

    // MARK: - Step 2 · Location

    private var locationStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60)).foregroundStyle(.white)
            VStack(spacing: 10) {
                Text("Turn on your location?")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("When you and your partner both turn it on, Us. shows how far apart you are and powers the distance widgets. You're in control — you can turn it off anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            Spacer()

            VStack(spacing: 12) {
                Button { enableLocation() } label: { Text("Turn on location") }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Not now") { session.completePersonalOnboarding() }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(28)
        .onChange(of: location.authorizationStatus) { _ in
            // The user answered the system prompt — continue to pairing.
            if !location.needsPermissionPrompt { session.completePersonalOnboarding() }
        }
    }

    private func enableLocation() {
        Haptics.tap()
        location.startSharing()
        // Already decided earlier (e.g. previously authorized) → continue now.
        if !location.needsPermissionPrompt { session.completePersonalOnboarding() }
    }
}
