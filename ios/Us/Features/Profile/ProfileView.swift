import SwiftUI
import PhotosUI
import UIKit

/// Navigation wrapper for presenting the profile editor as a standalone page
/// from Home. `ProfileEditView` itself stays reusable inside Settings' stack.
struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProfileEditView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(loc: "Done") { dismiss() }
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
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var uploadingAvatar = false
    @State private var avatarError: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Avatar(path: session.user?.avatarPath, name: session.user?.displayName, size: 64)
                    VStack(alignment: .leading, spacing: 6) {
                        Menu {
                            PhotosPicker(selection: $pickerItem, matching: .images,
                                         photoLibrary: .shared()) {
                                Label(loc: "Choose from library", systemImage: "photo.on.rectangle")
                            }
                            Button {
                                showCamera = true
                            } label: {
                                Label(loc: "Take a photo", systemImage: "camera")
                            }
                            if session.user?.avatarPath != nil {
                                Button(role: .destructive) {
                                    Task { await removeAvatar() }
                                } label: {
                                    Label(loc: "Remove photo", systemImage: "trash")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if uploadingAvatar {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Text(loc: session.user?.avatarPath == nil ? "Add a photo" : "Change photo")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .foregroundStyle(Theme.coral)
                        }
                        if let avatarError {
                            Text(avatarError).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section {
                TextField("Your name".loc, text: $nameDraft)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit { commitName() }

                Button { showEmailChange = true } label: {
                    HStack {
                        Text(loc: "Email")
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
                Text(loc: "Profile")
            }
        }
        .navigationTitle(Text(loc: "Edit"))
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await uploadAvatar(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadAvatar(image)
                }
                pickerItem = nil
            }
        }
    }

    private func uploadAvatar(_ image: UIImage) async {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        uploadingAvatar = true; avatarError = nil
        defer { uploadingAvatar = false }
        do {
            let updated = try await APIClient.shared.uploadAvatar(jpeg)
            session.applyUpdatedUser(updated)
            Haptics.success()
        } catch {
            avatarError = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func removeAvatar() async {
        uploadingAvatar = true; avatarError = nil
        defer { uploadingAvatar = false }
        do {
            let updated = try await APIClient.shared.deleteAvatar()
            session.applyUpdatedUser(updated)
            Haptics.tap(.light)
        } catch {
            avatarError = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
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
