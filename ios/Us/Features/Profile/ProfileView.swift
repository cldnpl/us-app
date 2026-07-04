import SwiftUI

/// Compact account glance presented from the profile icon in the Home nav bar.
/// Full settings live in the Settings tab.
struct ProfileView: View {
    @EnvironmentObject var session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Circle()
                        .fill(Theme.warmGradient)
                        .frame(width: 96, height: 96)
                        .overlay(Text(initials).font(.largeTitle.bold()).foregroundStyle(.white))
                        .padding(.top, 12)

                    VStack(spacing: 4) {
                        Text(session.user?.displayName ?? "You")
                            .font(.title2.bold())
                        if let email = session.user?.email {
                            Text(email).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    Card {
                        VStack(spacing: 12) {
                            row("Partner", session.partner?.displayName ?? "—", "heart.fill")
                            Divider()
                            row("Together", session.daysTogether.map { "\($0) days" } ?? "Set a start date", "calendar")
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
            .background(Theme.softBackground.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String, _ symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).foregroundStyle(Theme.rose)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private var initials: String {
        let name = session.user?.displayName ?? "?"
        return String(name.prefix(1)).uppercased()
    }
}
