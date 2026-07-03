import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var session: Session
    @State private var startDate = Date()
    @State private var showUnpairConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    LabeledContent("Name", value: session.user?.displayName ?? "—")
                    if let email = session.user?.email {
                        LabeledContent("Email", value: email)
                    }
                }

                Section("Your relationship") {
                    LabeledContent("Partner", value: session.partner?.displayName ?? "—")
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Button("Save start date") {
                        Task { await saveStartDate() }
                    }
                    if let days = session.daysTogether {
                        LabeledContent("Days together", value: "\(days)")
                    }
                }

                Section("Premium") {
                    HStack {
                        Label("Us. Premium", systemImage: "sparkles")
                        Spacer()
                        Text("€0.99 / mo").foregroundStyle(.secondary)
                    }
                    Text("Everything is free — Premium just raises the limits.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section {
                    Button("Sign out") { Task { await session.signOut() } }
                    Button("Unpair", role: .destructive) { showUnpairConfirm = true }
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                if let existing = session.couple?.startDate { startDate = existing }
            }
            .confirmationDialog("Unpair from your partner?", isPresented: $showUnpairConfirm, titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { Task { await unpair() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll both need to pair again to reconnect.")
            }
        }
    }

    private func saveStartDate() async {
        let iso = startDate.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        _ = try? await APIClient.shared.setStartDate(iso)
        await session.loadCouple()
        Haptics.success()
    }

    private func unpair() async {
        try? await APIClient.shared.unpair()
        await session.loadCouple()
    }
}
