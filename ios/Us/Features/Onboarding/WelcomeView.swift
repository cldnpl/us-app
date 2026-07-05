import SwiftUI
import AuthenticationServices

/// First screen (signed out): a clean landing to Register or Log in. The full
/// swipeable intro lives in onboarding (`IntroCarousel`) so everyone sees it —
/// including already-signed-in users who skip straight past this screen.
struct WelcomeView: View {
    enum AuthMode: Hashable { case register, login }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.warmGradient.ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
                    Text("Us.")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Two people, one little world.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                    Spacer()

                    VStack(spacing: 12) {
                        NavigationLink(value: AuthMode.register) {
                            Text("Create an account")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        NavigationLink(value: AuthMode.login) {
                            Text("Log in")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.white.opacity(0.85), lineWidth: 1.5)
                                )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthMode.self) { mode in
                AuthOptionsView(isRegister: mode == .register)
            }
        }
    }
}

/// The swipeable 4-page intro (icon + title + subtitle) with animated page dots.
/// Reused as the first step of onboarding so every new member sees the welcome.
struct IntroCarousel: View {
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(IntroPage.all.indices, id: \.self) { i in
                    IntroPageView(page: IntroPage.all[i])
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(IntroPage.all.indices, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i == page ? 1 : 0.45))
                        .frame(width: i == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                }
            }
        }
    }
}

/// One page of the intro carousel.
struct IntroPage: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String

    static let all: [IntroPage] = [
        .init(symbol: "heart.fill",
              title: "Welcome to Us.",
              subtitle: "Everything a couple needs — in one little app."),
        .init(symbol: "paperplane.fill",
              title: "Feel close, always",
              subtitle: "Send a little “thinking of you” that lands right on their widget."),
        .init(symbol: "map.fill",
              title: "Share your world",
              subtitle: "Watch the distance between you shrink, share moments, and count down to reunions."),
        .init(symbol: "heart.text.square.fill",
              title: "Care for each other",
              subtitle: "Cycle-aware tips so you always know how to show up for each other."),
    ]
}

/// A single, static intro page: icon + title + subtitle. The only motion is
/// swiping between pages — the content itself stays put (no pulsing or fading),
/// matching the calm, static look of the other onboarding screens.
struct IntroPageView: View {
    let page: IntroPage

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 34)
    }
}

/// Second screen: the provider options for the chosen intent.
struct AuthOptionsView: View {
    @EnvironmentObject var session: Session
    let isRegister: Bool

    @State private var showEmailSheet = false
    @State private var errorMessage: String?
    @State private var showGoogleNote = false

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()
                Text(isRegister ? "Create your account" : "Welcome back")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(isRegister ? "Choose how to sign up." : "Choose how to log in.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    googleButton

                    Button { showEmailSheet = true } label: {
                        Label("Continue with email", systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .tint(.white) // white back button on the pink gradient
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEmailSheet) {
            SignInView(isSignUp: isRegister)
        }
        .alert("Google sign-in coming soon", isPresented: $showGoogleNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Google sign-in still needs a bit of setup. For now, use Apple or email.")
        }
    }

    // Google needs the GoogleSignIn SDK + a backend endpoint; shows a note until wired up.
    private var googleButton: some View {
        Button { showGoogleNote = true } label: {
            HStack(spacing: 8) {
                Text("G")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Continue with Google").fontWeight(.medium)
            }
            .foregroundStyle(.black.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Could not read Apple credentials."
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            do {
                let resp = try await APIClient.shared.appleSignIn(identityToken: token, displayName: name)
                await session.handleAuth(resp)
            } catch {
                let backendMsg = ((error as? APIErrorResponse)?.error ?? "").lowercased()
                if backendMsg.contains("verify") || backendMsg.contains("token") || backendMsg.contains("apple") {
                    errorMessage = "Apple sign-in isn't available in this test build yet. Please use “Continue with email” — your name is asked right after."
                } else {
                    errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
