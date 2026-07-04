import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @State private var startDate = Date()
    @State private var pronoun: PartnerPronoun = PartnerPrefs.pronoun ?? .they
    @State private var showUnpairConfirm = false
    @State private var showAddWidget = false

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
                    Picker("Refer to \(partnerFirstName) as", selection: $pronoun) {
                        ForEach(PartnerPronoun.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    Button("Save start date") {
                        Task { await saveStartDate() }
                    }
                    if let days = session.daysTogether {
                        LabeledContent("Days together", value: "\(days)")
                    }
                }

                Section("Home Screen") {
                    Button {
                        showAddWidget = true
                    } label: {
                        Label("Add the Us. widget", systemImage: "plus.square.on.square")
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
            .navigationTitle("Settings")
            .onAppear {
                if let existing = session.couple?.startDate { startDate = existing }
                pronoun = PartnerPrefs.pronoun ?? .they
            }
            .onChange(of: pronoun) { new in session.setPartnerPronoun(new) }
            .sheet(isPresented: $showAddWidget) { AddWidgetGuideView() }
            .confirmationDialog("Unpair from your partner?", isPresented: $showUnpairConfirm, titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { Task { await unpair() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll both need to pair again to reconnect.")
            }
        }
    }

    private var partnerFirstName: String {
        (session.partner?.displayName ?? "them").split(separator: " ").first.map(String.init) ?? "them"
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
