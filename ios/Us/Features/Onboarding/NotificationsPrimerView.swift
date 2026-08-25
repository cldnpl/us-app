import SwiftUI

/// Asks for notifications *after* pairing, with a reason.
///
/// iOS presents its permission sheet once per install and never again: a
/// "Don't Allow" tapped by reflex is permanent, and the person is left
/// wondering for months why their partner's nudges never arrive. So this
/// screen goes first, says plainly what will be sent, and only then hands over
/// to the system sheet — and a "Not now" here costs nothing, because it leaves
/// iOS unasked and Settings ▸ App ▸ Notifications can still turn it on later.
struct NotificationsPrimerView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var session: Session
    @State private var asking = false

    /// Shown once, and only while asking is still possible.
    private static let shownKey = "didOfferNotifications"

    static func isNeeded() async -> Bool {
        guard !UserDefaults.standard.bool(forKey: shownKey) else { return false }
        return await PushManager.shared.canStillAsk
    }

    private var partnerName: String {
        (session.partner?.displayName).flatMap { $0.isEmpty ? nil : $0 } ?? "your partner"
    }

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()
            VStack(spacing: 26) {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    Text(loc: "Don't miss each other")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(loc: "Us only notifies you when \(partnerName) does something you'd want to know about.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)

                VStack(alignment: .leading, spacing: 14) {
                    row("questionmark.bubble.fill", "When it's your turn on a quiz — and when the results are ready")
                    row("book.closed.fill", "When \(partnerName) writes in your journal or adds a milestone")
                    row("sparkles", "The new Question of the Day, once every morning")
                }
                .padding(.horizontal, 4)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await allow() }
                    } label: {
                        if asking {
                            ProgressView().tint(.white).frame(maxWidth: .infinity)
                        } else {
                            Text(loc: "Turn on notifications").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(asking)

                    Button(loc: "Not now") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text(loc: "You can change this anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 8)
            }
            .padding(28)
        }
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func allow() async {
        asking = true
        await PushManager.shared.requestPermission()
        asking = false
        dismiss()
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        isPresented = false
    }
}
