import SwiftUI

struct SignInView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    /// Fixed by the choice made on the previous screen (Register vs Log in),
    /// so there's no mode toggle here.
    let isSignUp: Bool
    init(isSignUp: Bool = true) { self.isSignUp = isSignUp }

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                } footer: {
                    if isSignUp {
                        Text("At least 8 characters. You'll choose your name in the next step.")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading { ProgressView() } else { Text(isSignUp ? "Create account" : "Log in").bold() }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .navigationTitle(isSignUp ? "Create your account" : "Welcome back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 8
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp: AuthResponse
            if isSignUp {
                // Name isn't asked here — it's collected right after, in the
                // personal onboarding. Send a placeholder derived from the email.
                let placeholder = String((email.split(separator: "@").first ?? "there").prefix(30))
                resp = try await APIClient.shared.register(email: email, password: password,
                                                           displayName: placeholder)
            } else {
                resp = try await APIClient.shared.login(email: email, password: password)
            }
            await session.handleAuth(resp)
            dismiss()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
