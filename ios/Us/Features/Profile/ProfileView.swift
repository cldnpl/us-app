import SwiftUI

/// Compact account glance presented from the profile icon in the Home nav bar.
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
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Edit") { ProfileEditView() }
                }
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

/// Dedicated account editor. Profile fields stay out of the main Settings
/// form so settings remain a list of preferences rather than an inline editor.
struct ProfileEditView: View {
    @EnvironmentObject var session: Session
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool
    @State private var showEmailChange = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $nameDraft)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit { commitName() }

                Button { showEmailChange = true } label: {
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
                .tint(.primary)
            } header: {
                Text("Profile")
            }
        }
        .navigationTitle("Edit")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameDraft = session.user?.displayName ?? "" }
        .onChange(of: nameFocused) { focused in
            if !focused { commitName() }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { commitName() }
        }
        .onChange(of: session.user?.displayName) { newName in
            if !nameFocused, let newName { nameDraft = newName }
        }
        .onDisappear { commitName() }
        .sheet(isPresented: $showEmailChange) { ChangeEmailView() }
    }

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
}
