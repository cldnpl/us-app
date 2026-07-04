import SwiftUI
import AuthenticationServices

/// First screen: choose intent — Register or Log in. Picking one pushes to the
/// provider options (Apple / Google / email).
struct WelcomeView: View {
    enum AuthMode: Hashable { case register, login }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.warmGradient.ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()
                    Text("Us.")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
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
