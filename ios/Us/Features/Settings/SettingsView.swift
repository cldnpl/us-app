import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: Session
    @StateObject private var cycle = CycleManager.shared
    @ObservedObject private var languages = LanguageManager.shared
    @State private var startDate = Date()
    @State private var pronoun: PartnerPronoun = PartnerPrefs.pronoun ?? .they
    @State private var showUnpairConfirm = false
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
                    Button("Sign out") { Task { await session.signOut() } }
                    Button("Unpair", role: .destructive) { showUnpairConfirm = true }
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
            .sheet(isPresented: $showEmailChange) { ChangeEmailView() }
            .confirmationDialog("Unpair from your partner?", isPresented: $showUnpairConfirm, titleVisibility: .visible) {
                Button("Unpair", role: .destructive) { Task { await unpair() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll both need to pair again to reconnect.")
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
}
