import SwiftUI

struct PairingView: View {
    @EnvironmentObject var session: Session

    @State private var generatedCode: String?
    @State private var enteredCode = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.coral)
                        Text("Connect with your partner")
                            .font(.title2.bold())
                        Text("Share a code, or enter the one your partner gives you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    Card {
                        VStack(spacing: 14) {
                            Text("Invite your partner").font(.headline)
                            if let code = generatedCode {
                                Text(code)
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                    .kerning(6)
                                    .foregroundStyle(Theme.coral)
                                Text("Share this code with your partner")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                ShareLink(item: "Join me on Us. 💜 Use my pairing code: \(code)") {
                                    Label("Share code", systemImage: "square.and.arrow.up")
                                }
                                Button("I'm connected — continue") {
                                    Task { await session.loadCouple() }
                                }
                                .font(.footnote)
                            } else {
                                ProgressView()
                                    .padding(.vertical, 10)
                                Text("Preparing your code…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Card {
                        VStack(spacing: 14) {
                            Text("I have a code").font(.headline)
                            TextField("Enter code", text: $enteredCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.center)
                                .font(.title2.monospaced())
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                            Button {
                                Task { await redeem() }
                            } label: {
                                if isLoading { ProgressView() } else { Text("Connect") }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(!canConnect || isLoading)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }

                    Button("Sign out") { Task { await session.signOut() } }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .task {
            if generatedCode == nil { await generate() }
        }
    }

    private func generate() async {
        errorMessage = nil
        do {
            let code = try await APIClient.shared.createPairingCode()
            generatedCode = code.code
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    /// Whether the Connect button is enabled. Real codes are 6 chars.
    private var canConnect: Bool {
        let code = enteredCode.trimmingCharacters(in: .whitespaces)
        if SharedConfig.demoMode, code == "0000" { return true } // TEST ONLY — see redeem()
        return code.count >= 6
    }

    private func redeem() async {
        let code = enteredCode.trimmingCharacters(in: .whitespaces).uppercased()
        // TEST ONLY (SharedConfig.demoMode): "0000" opens the app without a real
        // partner so the UI can be tested. Turn off via SharedConfig.demoMode.
        if SharedConfig.demoMode, code == "0000" {
            Haptics.success()
            session.enterTestPairing()
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.redeemPairing(code: code)
            Haptics.success()
            await session.loadCouple()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
