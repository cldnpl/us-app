import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var session: Session
    @State private var showEmailSheet = false
    @State private var errorMessage: String?

    var body: some View {
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
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleApple(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        showEmailSheet = true
                    } label: {
                        Text("Continue with email")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            SignInView()
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
                errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
