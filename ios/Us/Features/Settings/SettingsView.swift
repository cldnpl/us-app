import SwiftUI
import UserNotifications

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
    /// Whether iOS is currently letting Us notify this person. Read on appear
    /// and whenever the app comes back — the only place it can change is the
    /// system Settings app, which means leaving and returning.
    @State private var notificationsAllowed: Bool?

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }

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

                appleHealthSection

                Section("App") {
                    NavigationLink {
                        LanguagePickerView()
                    } label: {
                        LabeledContent("Language") {
                            Text(verbatim: languages.current.endonym)
                        }
                    }
                    notificationsRow
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
            .task { await cycle.refreshOnAppear() }
            .onAppear {
                if let existing = session.couple?.startDate { startDate = existing }
                pronoun = PartnerPrefs.pronoun ?? .they
            }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await refreshNotificationStatus() } }
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

    /// Notification state, and the way back when they're off: iOS only ever
    /// asks once, so a person who declined (or never saw the prompt) otherwise
    /// has no clue why their partner's nudges never arrive.
    @ViewBuilder
    private var notificationsRow: some View {
        switch notificationsAllowed {
        case .some(true):
            LabeledContent("Notifications") { Text("On").foregroundStyle(.secondary) }
        case .some(false):
            Button {
                Task { await enableNotifications() }
            } label: {
                LabeledContent("Notifications") {
                    Text("Off").foregroundStyle(Theme.rose)
                }
            }
            .tint(.primary)
        case nil:
            LabeledContent("Notifications") { ProgressView() }
        }
    }

    private func refreshNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsAllowed = (status == .authorized || status == .provisional)
    }

    /// Asks iOS if it hasn't been asked yet, otherwise sends the person to the
    /// system settings — after a refusal, only they can undo it.
    private func enableNotifications() async {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            await PushManager.shared.requestPermission()
            await refreshNotificationStatus()
            return
        }
        if let url = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(url)
        }
    }

    /// Identification of the HealthKit integration, shown to everyone — whatever
    /// they answered about having a cycle — because the app ships the capability.
    private var appleHealthSection: some View {
        Section {
            LabeledContent("Apple Health") {
                Text(healthConnected ? "Connected" : "Not connected")
                    .foregroundStyle(.secondary)
            }
            if cycle.userHasCycle == true, !healthConnected, HealthKitManager.shared.isAvailable {
                Button {
                    Task { await cycle.connectHealth() }
                } label: {
                    Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                }
            }
            Link(destination: AppleHealth.appURL) {
                Label("Open the Health app", systemImage: "arrow.up.forward.app")
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("\(AppleHealth.readsLine) \(AppleHealth.neverWritesLine) \(AppleHealth.manageLine)")
        }
    }

    /// HealthKit never reveals read permission, so "connected" means the app has
    /// completed the permission sheet on this iPhone (or has read real data at
    /// some point). It's remembered across relaunches and sign-outs, so the row
    /// doesn't flip back to "Not connected" whenever a read comes back empty.
    private var healthConnected: Bool { cycle.isHealthConnected }

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
