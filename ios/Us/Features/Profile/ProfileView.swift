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
    @ObservedObject private var cycle = CycleManager.shared
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool
    @State private var showEmailChange = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showLibraryPicker = false
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
                            // PhotosPicker inside a Menu doesn't reliably present on
                            // iOS — the menu dismisses without ever opening the
                            // library sheet. Route through a state flag and let the
                            // `.photosPicker(isPresented:)` modifier below own the
                            // presentation instead.
                            Button {
                                showLibraryPicker = true
                            } label: {
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

            Section {
                Toggle("I have a menstrual cycle".loc, isOn: Binding(
                    get: { cycle.userHasCycle == true },
                    set: { cycle.setUserHasCycle($0) }
                ))
            } header: {
                Text(loc: "You")
            } footer: {
                Text(loc: "Off if you're supporting a partner who has one.")
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
        .photosPicker(isPresented: $showLibraryPicker, selection: $pickerItem,
                      matching: .images, photoLibrary: .shared())
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
            // Invalidate any cached image at the *previous* avatar path so a
            // fallback to the old URL can't linger. Older server builds don't
            // version the avatar URL, so this is how the swap becomes instant.
            let previousPath = session.user?.avatarPath
            let updated = try await APIClient.shared.uploadAvatar(jpeg)
            primeAvatarCache(newJPEG: jpeg, uploaded: image, previousPath: previousPath, newPath: updated.avatarPath)
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
            let previousPath = session.user?.avatarPath
            let updated = try await APIClient.shared.deleteAvatar()
            if let previousPath { invalidateAvatarPath(previousPath) }
            session.applyUpdatedUser(updated)
            Haptics.tap(.light)
        } catch {
            avatarError = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    /// Drops any cached bytes for the given avatar URL and tells every visible
    /// RemoteImage bound to it to reload.
    private func invalidateAvatarPath(_ path: String) {
        ImageCache.shared.remove(for: path)
        NotificationCenter.default.post(name: .imageCacheInvalidated,
                                        object: nil, userInfo: ["path": path])
    }

    /// Refreshes the avatar cache after an upload: purges the stale bytes at
    /// both the previous and new URL, seeds the new URL with the JPEG we just
    /// sent (so the swap is visible without a round-trip), and nudges any
    /// visible avatars to reload.
    private func primeAvatarCache(newJPEG: Data, uploaded: UIImage,
                                  previousPath: String?, newPath: String?) {
        if let previousPath { invalidateAvatarPath(previousPath) }
        guard let newPath else { return }
        ImageCache.shared.remove(for: newPath)
        // Server re-encodes; use the local image as a warm placeholder so the
        // switch is immediate. RemoteImage's reload will replace it with the
        // server's canonical bytes once fetched.
        if let seed = UIImage(data: newJPEG) ?? Optional(uploaded) {
            ImageCache.shared.set(seed, for: newPath)
        }
        NotificationCenter.default.post(name: .imageCacheInvalidated,
                                        object: nil, userInfo: ["path": newPath])
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
