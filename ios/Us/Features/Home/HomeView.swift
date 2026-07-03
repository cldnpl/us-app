import SwiftUI

struct HomeView: View {
    @EnvironmentObject var session: Session
    @State private var missYouSent = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        partnerCard
                        missYouButton
                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Us.")
        }
    }

    private var partnerCard: some View {
        Card {
            VStack(spacing: 12) {
                Circle()
                    .fill(Theme.warmGradient)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Text(initials)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                    )
                Text(session.partner?.displayName ?? "Your partner")
                    .font(.title2.bold())
                if let days = session.daysTogether {
                    Text("\(days) days together 💜")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Set your start date in Profile")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var missYouButton: some View {
        Button {
            Task { await sendMissYou() }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: missYouSent ? "heart.fill" : "heart")
                    .font(.system(size: 44))
                Text(missYouSent ? "Sent 💜" : "Miss You")
                    .font(.title3.bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Theme.warmGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.coral.opacity(0.4), radius: 16, y: 8)
        }
        .disabled(isSending)
    }

    private var initials: String {
        let name = session.partner?.displayName ?? "?"
        return String(name.prefix(1)).uppercased()
    }

    private func sendMissYou() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            _ = try await APIClient.shared.sendMissYou()
            Haptics.tap(.heavy)
            withAnimation { missYouSent = true }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { missYouSent = false }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
