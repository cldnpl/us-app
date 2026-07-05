import SwiftUI

/// "About you" onboarding, shown once right after sign-in and before pairing:
/// 1. confirm your name,
/// 2. choose whether to turn on location (for distance features & widgets).
///
/// Apple HIG: we explain *why* before triggering the system location prompt.
struct PersonalOnboardingView: View {
    @EnvironmentObject var session: Session
    @StateObject private var location = LocationManager.shared

    @State private var step: Step = .welcome
    @State private var name = ""
    @State private var saving = false

    enum Step { case welcome, name, cycle, location }

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()
            Group {
                switch step {
                case .welcome: welcomeStep
                case .name: nameStep
                case .cycle: cycleStep
                case .location: locationStep
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .overlay(alignment: .top) { if step != .welcome { stepDots.padding(.top, 10) } }
        .onAppear { if name.isEmpty { name = session.user?.displayName ?? "" } }
    }

    private var stepIndex: Int {
        switch step {
        case .welcome, .name: return 0
        case .cycle: return 1
        case .location: return 2
        }
    }

    // MARK: - Step 0 · Welcome intro (the swipeable carousel)

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            IntroCarousel()
            Button { withAnimation { step = .name } } label: { Text("Get started") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 40)
        }
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i == stepIndex ? 1 : 0.4))
                    .frame(width: i == stepIndex ? 20 : 7, height: 7)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: stepIndex)
            }
        }
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
        withAnimation { step = .cycle }
    }

    // MARK: - Step 2 · Cycle

    private var cycleStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60)).foregroundStyle(.white)
            VStack(spacing: 10) {
                Text("Do you have a\nmenstrual cycle?")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("This tailors Us. for you — track your own cycle, or get gentle tips to support your partner's. You can change it anytime.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            Spacer()

            VStack(spacing: 12) {
                Button { chooseCycle(true) } label: { Text("Yes, I do") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { chooseCycle(false) } label: {
                    Text("No, I don't")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(28)
    }

    private func chooseCycle(_ hasCycle: Bool) {
        Haptics.tap()
        CycleManager.shared.setUserHasCycle(hasCycle)
        withAnimation { step = .location }
    }

    // MARK: - Step 3 · Location

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
