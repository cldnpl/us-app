import SwiftUI
import UserNotifications

/// Root Settings screen. Each domain (profile, relationship, health, …) lives
/// in its own dedicated page so the top-level list stays scannable.
struct SettingsView: View {
    @EnvironmentObject var session: Session
    @EnvironmentObject private var premium: PremiumStore
    @ObservedObject private var languages = LanguageManager.shared
    @State private var notificationsAllowed: Bool?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { ProfileEditView() } label: {
                        Label {
                            Text(loc: "Profile")
                        } icon: {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(Theme.coral)
                        }
                    }
                    NavigationLink { RelationshipSettingsView() } label: {
                        Label {
                            Text(loc: "Relationship")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(Theme.rose)
                        }
                    }
                    NavigationLink { AppleHealthSettingsView() } label: {
                        Label {
                            Text(loc: "Apple Health")
                        } icon: {
                            // The system red-heart glyph mirrors the Apple
                            // Health app icon so the row is instantly
                            // recognisable next to Profile / Relationship.
                            Image(systemName: "heart.text.square.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section(header: Text(loc: "App")) {
                    NavigationLink { LanguagePickerView() } label: {
                        HStack {
                            Label {
                                Text(loc: "Language")
                            } icon: {
                                Image(systemName: "globe").foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(verbatim: languages.current.endonym)
                                .foregroundStyle(.secondary)
                        }
                    }
                    notificationsRow
                }

                Section {
                    NavigationLink { PremiumSettingsView() } label: {
                        HStack {
                            Label {
                                Text(loc: "Us. Premium")
                            } icon: {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Theme.coral)
                            }
                            Spacer()
                            Text(premium.isPremium
                                 ? (PremiumStore.isTestFlightBuild ? "Beta".loc : "Active".loc)
                                 : premium.priceLine)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    NavigationLink { AccountSettingsView() } label: {
                        Label {
                            Text(loc: "Account")
                        } icon: {
                            Image(systemName: "person.badge.key.fill")
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
            .navigationTitle(Text(loc: "Settings"))
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await refreshNotificationStatus() } }
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
            HStack {
                Label {
                    Text(loc: "Notifications")
                } icon: {
                    Image(systemName: "bell.fill").foregroundStyle(Theme.coral)
                }
                Spacer()
                Text(loc: "On").foregroundStyle(.secondary)
            }
        case .some(false):
            Button {
                Task { await enableNotifications() }
            } label: {
                HStack {
                    Label {
                        Text(loc: "Notifications")
                    } icon: {
                        Image(systemName: "bell.fill").foregroundStyle(Theme.coral)
                    }
                    Spacer()
                    Text(loc: "Off").foregroundStyle(Theme.rose)
                }
            }
            .tint(.primary)
        case nil:
            HStack {
                Label {
                    Text(loc: "Notifications")
                } icon: {
                    Image(systemName: "bell.fill").foregroundStyle(Theme.coral)
                }
                Spacer()
                ProgressView()
            }
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
}

// MARK: - Relationship

/// Everything about "us": who the partner is, how to refer to them, and when
/// the relationship began.
struct RelationshipSettingsView: View {
    @EnvironmentObject var session: Session
    @State private var startDate = Date()
    @State private var pronoun: PartnerPronoun = PartnerPrefs.pronoun ?? .they

    var body: some View {
        Form {
            Section {
                LabeledContent("Partner".loc, value: session.partner?.displayName ?? "—")
                Picker("Refer to \(partnerFirstName) as".loc, selection: $pronoun) {
                    ForEach(PartnerPronoun.allCases) { Text($0.label).tag($0) }
                }
            } header: {
                Text(loc: "Your partner")
            }

            Section {
                DatePicker("Together since".loc, selection: $startDate,
                           in: ...Date(), displayedComponents: .date)
                LabeledContent("Days together".loc, value: "\(liveDays)")
            }
        }
        .navigationTitle(Text(loc: "Relationship"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let existing = session.couple?.startDate { startDate = existing }
            pronoun = PartnerPrefs.pronoun ?? .they
        }
        .onChange(of: pronoun) { new in session.setPartnerPronoun(new) }
        .onChange(of: startDate) { newDate in
            let savedDay = session.couple?.startDate.map { Calendar.current.startOfDay(for: $0) }
            if Calendar.current.startOfDay(for: newDate) != savedDay {
                Task { await session.saveStartDate(newDate); Haptics.success() }
            }
        }
    }

    private var partnerFirstName: String {
        (session.partner?.displayName ?? "them").split(separator: " ").first.map(String.init) ?? "them"
    }

    private var liveDays: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: startDate),
                                         to: cal.startOfDay(for: Date())).day ?? 0)
    }
}

// MARK: - Apple Health

/// HealthKit connection status + entry point into the Health app.
struct AppleHealthSettingsView: View {
    @ObservedObject private var cycle = CycleManager.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Apple Health".loc) {
                    Text(cycle.isHealthConnected ? "Connected" : "Not connected")
                        .foregroundStyle(.secondary)
                }
                if cycle.userHasCycle == true, !cycle.isHealthConnected, HealthKitManager.shared.isAvailable {
                    Button {
                        Task { await cycle.connectHealth() }
                    } label: {
                        Label(loc: "Connect Apple Health", systemImage: "heart.text.square.fill")
                    }
                }
                Link(destination: AppleHealth.appURL) {
                    Label(loc: "Open the Health app", systemImage: "arrow.up.forward.app")
                }
            } footer: {
                Text(loc: "\(AppleHealth.readsLine) \(AppleHealth.neverWritesLine) \(AppleHealth.manageLine)")
            }
        }
        .navigationTitle(Text(loc: "Apple Health"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Premium

/// Subscription state, price, restore, and (in debug) the dev unlock switch.
struct PremiumSettingsView: View {
    @EnvironmentObject private var premium: PremiumStore
    @State private var showPaywall = false

    var body: some View {
        Form {
            Section {
                if premium.isPremium {
                    HStack {
                        Label(loc: "Us. Premium", systemImage: "sparkles")
                        Spacer()
                        Text(PremiumStore.isTestFlightBuild ? "Beta" : "Active")
                            .foregroundStyle(.secondary)
                    }
                    if !PremiumStore.isTestFlightBuild {
                        Link("Manage subscription".loc,
                             destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label(loc: "Unlock Us. Premium", systemImage: "sparkles")
                            Spacer()
                            Text(premium.priceLine).foregroundStyle(.secondary)
                        }
                    }
                    Button(loc: "Restore purchase") { Task { await premium.restore() } }
                        .disabled(premium.isRestoring)
                }
                #if DEBUG
                Toggle("Dev: unlock Premium".loc, isOn: Binding(
                    get: { PremiumStore.devUnlock },
                    set: { premium.setDevUnlock($0) }
                ))
                #endif
            } footer: {
                if PremiumStore.isTestFlightBuild {
                    Text(loc: "Thanks for testing Us. — every quiz pack and game is unlocked for you while the app is in beta.")
                } else if premium.isPremium {
                    Text(loc: "Every quiz pack and game is unlocked for both of you.")
                } else {
                    Text(loc: "Starters, Relationship and How Well Do You Know Me? are free. Premium unlocks every other pack and game, for both of you.")
                }
            }
        }
        .navigationTitle(Text(loc: "Premium"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

// MARK: - Account

/// Sign out, unpair, delete — all separated from the day-to-day settings so a
/// destructive tap can't be an accident of scrolling.
struct AccountSettingsView: View {
    @EnvironmentObject var session: Session
    @State private var showUnpairConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            Section {
                Button(loc: "Sign out") { Task { await session.signOut() } }
            }
            Section {
                Button(loc: "Unpair", role: .destructive) { showUnpairConfirm = true }
                Button(loc: "Delete account", role: .destructive) { showDeleteConfirm = true }
            } footer: {
                Text(loc: "Unpairing keeps your account. Deleting removes it forever.")
            }
        }
        .navigationTitle(Text(loc: "Account"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Text(loc: "Unpair from your partner?"), isPresented: $showUnpairConfirm, titleVisibility: .visible) {
            Button(loc: "Unpair", role: .destructive) { Task { await unpair() } }
            Button(loc: "Cancel", role: .cancel) {}
        } message: {
            Text(loc: "You'll both need to pair again to reconnect.")
        }
        .confirmationDialog(Text(loc: "Delete your account?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(loc: "Delete forever", role: .destructive) { Task { await deleteAccount() } }
            Button(loc: "Cancel", role: .cancel) {}
        } message: {
            Text(loc: "This permanently removes your account, journal entries and photos. It can't be undone.")
        }
    }

    private func unpair() async {
        try? await APIClient.shared.unpair()
        await session.loadCouple()
    }

    private func deleteAccount() async {
        try? await APIClient.shared.deleteAccount()
        await session.signOut()
    }
}
