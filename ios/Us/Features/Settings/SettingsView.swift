import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject private var premium: PremiumStore
    @StateObject private var cycle = CycleManager.shared
    @State private var showPaywall = false
    @ObservedObject private var languages = LanguageManager.shared
    @State private var startDate = Date()
    @State private var pronoun: PartnerPronoun = PartnerPrefs.pronoun ?? .they
    @State private var showUnpairConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showAddWidget = false
    @State private var showEmailChange = false

    /// Draft of the display name. Committed on blur or return, not per
    /// keystroke, so we don't PATCH the server on every letter typed.
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("Your name", text: $nameDraft)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .focused($nameFocused)
                            .onSubmit { commitName() }
                    }

                    Button { showEmailChange = true } label: { emailRow }
                        .tint(.primary)

                    Toggle("I have a menstrual cycle", isOn: Binding(
                        get: { cycle.userHasCycle == true },
                        set: { cycle.setUserHasCycle($0) }
                    ))
                } header: {
                    Text("You")
                } footer: {
                    Text("Off if you're supporting a partner who has one.")
                }

                Section("Your relationship") {
                    LabeledContent("Partner", value: session.partner?.displayName ?? "—")
                    Picker("Refer to \(partnerFirstName) as", selection: $pronoun) {
                        ForEach(PartnerPronoun.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker("Together since", selection: $startDate,
                               in: ...Date(), displayedComponents: .date)
                    LabeledContent("Days together", value: "\(liveDays)")
                }

                Section("App") {
                    NavigationLink {
                        LanguagePickerView()
                    } label: {
                        LabeledContent("Language") {
                            Text(verbatim: languages.current.endonym)
                        }
                    }
                }

                Section("Home Screen") {
                    Button {
                        showAddWidget = true
                    } label: {
                        Label("Add the Us. widget", systemImage: "plus.square.on.square")
                    }
                }

                Section {
                    if premium.isPremium {
                        HStack {
                            Label("Us. Premium", systemImage: "sparkles")
                            Spacer()
                            Text(PremiumStore.isTestFlightBuild ? "Beta" : "Active")
                                .foregroundStyle(.secondary)
                        }
                        if !PremiumStore.isTestFlightBuild {
                            Link("Manage subscription",
                                 destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Unlock Us. Premium", systemImage: "sparkles")
                                Spacer()
                                Text(premium.priceLine).foregroundStyle(.secondary)
                            }
                        }
                        Button("Restore purchase") { Task { await premium.restore() } }
                            .disabled(premium.isRestoring)
                    }
                    #if DEBUG
                    Toggle("Dev: unlock Premium", isOn: Binding(
                        get: { PremiumStore.devUnlock },
                        set: { premium.setDevUnlock($0) }
                    ))
                    #endif
                } header: {
                    Text("Premium")
                } footer: {
                    if PremiumStore.isTestFlightBuild {
                        Text("Thanks for testing Us. — every quiz pack and game is unlocked for you while the app is in beta.")
                    } else if premium.isPremium {
                        Text("Every quiz pack and game is unlocked for both of you.")
                    } else {
                        Text("Starters, Relationship and How Well Do You Know Me? are free. Premium unlocks every other pack and game, for both of you.")
                    }
                }

                Section {
                    Button("Sign out") { Task { await session.signOut() } }
                    Button("Unpair", role: .destructive) { showUnpairConfirm = true }
                    Button("Delete account", role: .destructive) { showDeleteConfirm = true }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if let existing = session.couple?.startDate { startDate = existing }
                pronoun = PartnerPrefs.pronoun ?? .they
                nameDraft = session.user?.displayName ?? ""
            }
            // Tapping an inert part of a Form doesn't drop focus, so blur alone
            // would silently lose a typed name. Commit on every way out of the
            // screen: blur, Return, leaving the tab, and backgrounding the app.
            .onChange(of: nameFocused) { focused in
                if !focused { commitName() }
            }
            .onDisappear { commitName() }
            .onChange(of: scenePhase) { phase in
                if phase != .active { commitName() }
            }
            .onChange(of: session.user?.displayName) { newName in
                // Keep the field in step when the name changes elsewhere (a
                // foreground refresh, say) and the user isn't mid-edit.
                if !nameFocused, let newName { nameDraft = newName }
            }
            .onChange(of: pronoun) { new in session.setPartnerPronoun(new) }
            .onChange(of: startDate) { newDate in
                // Auto-save when the picked day actually differs from the saved
                // one (so it doesn't fire on the initial load).
                let savedDay = session.couple?.startDate.map { Calendar.current.startOfDay(for: $0) }
                if Calendar.current.startOfDay(for: newDate) != savedDay {
                    // Use the session helper so the test-mode persistence
                    // (testStartDate) + widget update happen. Don't call a local
                    // saveStartDate that goes through loadCouple → reset.
                    Task { await session.saveStartDate(newDate); Haptics.success() }
                }
            }
            .sheet(isPresented: $showAddWidget) { AddWidgetGuideView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showEmailChange) { ChangeEmailView() }
            .confirmationDialog("Unpair from your partner?", isPresented: $showUnpairConfirm, titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { Task { await unpair() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll both need to pair again to reconnect.")
            }
            .confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete forever", role: .destructive) { Task { await deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your account, journal entries and photos. It can't be undone.")
            }
        }
    }

    /// The email row: current address plus a disclosure chevron.
    private var emailRow: some View {
        HStack {
            Text("Email")
            Spacer()
            Text(session.user?.email ?? "Add")
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// Saves the name if it actually changed, reverting an empty field rather
    /// than sending a blank name the server would reject.
    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameDraft = session.user?.displayName ?? ""
            return
        }
        guard trimmed != session.user?.displayName else { return }
        nameDraft = trimmed
        Task { await session.updateName(trimmed); Haptics.success() }
    }

    private var partnerFirstName: String {
        (session.partner?.displayName ?? "them").split(separator: " ").first.map(String.init) ?? "them"
    }

    /// Days together computed live from the currently-picked start date.
    private var liveDays: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: startDate),
                                         to: cal.startOfDay(for: Date())).day ?? 0)
    }

    private func unpair() async {
        try? await APIClient.shared.unpair()
        await session.loadCouple()
    }

    private func deleteAccount() async {
        try? await APIClient.shared.deleteAccount()
        // The account is gone server-side; drop all local state too.
        await session.signOut()
    }
}
