import SwiftUI
import PhotosUI

/// Composer for a diary entry: pick a day, write some words and/or attach
/// photos — from the library or taken there and then. Saving adds a new entry
/// for that day (you can write as many per day as you like) or rewrites the one
/// being edited, then uploads the photos that were attached.
struct AddJournalEntrySheet: View {
    let existing: JournalEntry?
    let onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var text: String
    @State private var existingPhotos: [MediaItem]
    @State private var picks: [PhotosPickerItem] = []
    /// Photos attached in this session, already decoded so they can be shown
    /// as real thumbnails before saving.
    @State private var newPhotos: [PendingPhoto] = []
    @State private var loadingPicks = false
    @State private var showCamera = false
    @State private var saving = false
    @State private var progress: String?
    @State private var errorMessage: String?

    /// A photo chosen but not uploaded yet: the image to show in the strip and
    /// the JPEG that will be sent on save.
    private struct PendingPhoto: Identifiable {
        let id = UUID()
        let image: UIImage
        let jpeg: Data
    }

    init(existing: JournalEntry?, onDone: @escaping () async -> Void) {
        self.existing = existing
        self.onDone = onDone
        _date = State(initialValue: existing.map { pickerDay($0.date) } ?? Date())
        _text = State(initialValue: existing?.body ?? "")
        _existingPhotos = State(initialValue: existing?.photos ?? [])
    }

    private var isEditing: Bool { existing != nil }
    private var trimmedBody: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !trimmedBody.isEmpty || !newPhotos.isEmpty || !existingPhotos.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day".loc, selection: $date, in: ...Date(), displayedComponents: .date)
                        .disabled(isEditing)
                }

                Section(header: Text(loc: "Words")) {
                    TextField("What happened today?".loc, text: $text, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section(header: Text(loc: "Photos")) {
                    if !existingPhotos.isEmpty || !newPhotos.isEmpty || loadingPicks {
                        photoStrip
                    }
                    PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                        Label(loc: "Choose from library", systemImage: "photo.on.rectangle")
                    }
                    .disabled(loadingPicks)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label(loc: "Take a photo", systemImage: "camera.fill")
                        }
                        .disabled(loadingPicks)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(isEditing ? "Edit day" : "New entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc: "Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? (progress ?? "Saving…") : "Save") { Task { await save() } }
                        .disabled(!canSave || saving)
                }
            }
            .onChange(of: picks) { newPicks in Task { await attach(newPicks) } }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in attach(image) }
                    .ignoresSafeArea()
            }
            .interactiveDismissDisabled(saving)
        }
    }

    /// Everything attached to this entry, saved and unsaved alike, so you can
    /// see what you picked instead of a count.
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(existingPhotos) { item in
                    thumbnail {
                        RemoteImage(path: item.thumbUrl)
                    } remove: {
                        // Only the person who uploaded a photo may remove it.
                        item.uploaderId == existing?.authorId
                            ? { Task { await removeExisting(item) } } : nil
                    }
                }
                ForEach(newPhotos) { pending in
                    thumbnail {
                        Image(uiImage: pending.image).resizable().scaledToFill()
                    } remove: {
                        { newPhotos.removeAll { $0.id == pending.id } }
                    }
                }
                if loadingPicks {
                    ProgressView()
                        .frame(width: 72, height: 72)
                        .background(Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func thumbnail<Content: View>(@ViewBuilder _ content: () -> Content,
                                          remove: () -> (() -> Void)?) -> some View {
        let onRemove = remove()
        return content()
            .frame(width: 72, height: 72)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(3)
                }
            }
    }

    // MARK: - Attaching

    /// Decodes the library picks into thumbnails, then clears the picker so the
    /// same photo can be chosen again later in the same session.
    private func attach(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        loadingPicks = true
        defer { loadingPicks = false; picks = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            attach(image)
        }
    }

    private func attach(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        newPhotos.append(PendingPhoto(image: image, jpeg: jpeg))
    }

    private func removeExisting(_ item: MediaItem) async {
        do {
            try await APIClient.shared.deletePhoto(id: item.id)
            existingPhotos.removeAll { $0.id == item.id }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        defer { saving = false; progress = nil }
        do {
            let entry: JournalEntry
            if let existing {
                entry = try await APIClient.shared.updateJournalEntry(id: existing.id, body: trimmedBody)
            } else {
                entry = try await APIClient.shared.createJournalEntry(date: isoDay(date), body: trimmedBody)
            }
            let total = newPhotos.count
            for (i, photo) in newPhotos.enumerated() {
                if total > 1 { progress = "Photo \(i + 1)/\(total)" }
                _ = try await APIClient.shared.uploadJournalPhoto(entryId: entry.id, photo.jpeg)
            }
            Haptics.success()
            await onDone()
            dismiss()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
