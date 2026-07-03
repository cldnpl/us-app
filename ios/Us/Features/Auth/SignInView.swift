import SwiftUI

struct SignInView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = true
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $isSignUp) {
                        Text("Sign up").tag(true)
                        Text("Log in").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if isSignUp {
                        TextField("Your name", text: $displayName)
                            .textContentType(.givenName)
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
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
        email.contains("@") && password.count >= 8 && (!isSignUp || !displayName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let resp: AuthResponse
            if isSignUp {
                resp = try await APIClient.shared.register(email: email, password: password,
                                                           displayName: displayName)
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
