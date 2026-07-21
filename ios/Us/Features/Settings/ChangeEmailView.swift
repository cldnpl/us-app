import SwiftUI

/// Two-step email change: enter the new address, then the code we mail to it.
///
/// The code goes to the *new* address on purpose — receiving it is what proves
/// the address is real and reachable. Nothing on the account changes until the
/// code is confirmed, so abandoning the sheet halfway is harmless.
struct ChangeEmailView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    private enum Step { case address, code }
    @State private var step: Step = .address

    @State private var newEmail = ""
    @State private var code = ""
    @State private var sentTo = ""
    /// Only ever set by a dev server with no mail provider configured.
    @State private var devCode: String?

    @State private var busy = false
    @State private var errorMessage: String?

    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .address: addressStep
                case .code: codeStep
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Change email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button(step == .address ? "Send code" : "Confirm") {
                            Task { step == .address ? await sendCode() : await confirmCode() }
                        }
                        .disabled(step == .address ? !emailLooksValid : code.count < 6)
                    }
                }
            }
            .onAppear { focused = true }
        }
    }

    private var addressStep: some View {
        Section {
            TextField("new@email.com", text: $newEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
        } header: {
            Text("New email")
        } footer: {
            Text("We'll send a code there to confirm it's yours.")
        }
    }

    private var codeStep: some View {
        Section {
            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)

            Button("Send a new code") {
                Task { await sendCode() }
            }
            .font(.footnote)
            .disabled(busy)
        } header: {
            Text("Code sent to \(sentTo)")
        } footer: {
            if let devCode {
                // No mail provider is configured on this server, so there is no
                // inbox to read — show the code rather than dead-ending.
                Text("Dev server: no email configured. Your code is \(devCode).")
            } else {
                Text("Check your inbox. The code expires in 15 minutes.")
            }
        }
    }

    private var emailLooksValid: Bool {
        let trimmed = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    private func sendCode() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            let resp = try await APIClient.shared.requestEmailChange(
                newEmail: newEmail.trimmingCharacters(in: .whitespacesAndNewlines))
            sentTo = resp.sentTo
            devCode = resp.devCode
            code = ""
            step = .code
            focused = true
        } catch let apiError as APIErrorResponse {
            errorMessage = apiError.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmCode() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            let updated = try await APIClient.shared.confirmEmailChange(
                code: code.trimmingCharacters(in: .whitespacesAndNewlines))
            session.applyUpdatedUser(updated)
            Haptics.success()
            dismiss()
        } catch let apiError as APIErrorResponse {
            errorMessage = apiError.error
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
