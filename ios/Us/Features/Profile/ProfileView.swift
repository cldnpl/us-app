import SwiftUI

/// Navigation wrapper for presenting the profile editor as a standalone page
/// from Home. `ProfileEditView` itself stays reusable inside Settings' stack.
struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfileEditView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// Dedicated account editor presented as its own page, not inline in Settings.
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
