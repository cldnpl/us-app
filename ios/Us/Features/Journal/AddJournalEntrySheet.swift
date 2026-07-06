import SwiftUI
import PhotosUI

/// Composer for a diary entry: pick a day, write some words and/or attach
/// photos. Saving upserts *your* entry for that day (the partner keeps theirs),
/// then uploads any newly picked photos.
struct AddJournalEntrySheet: View {
    let existing: JournalEntry?
    let onDone: () async -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var text: String
    @State private var existingPhotos: [MediaItem]
    @State private var picks: [PhotosPickerItem] = []
    @State private var newCount = 0
    @State private var saving = false
    @State private var progress: String?
    @State private var errorMessage: String?

    init(existing: JournalEntry?, onDone: @escaping () async -> Void) {
        self.existing = existing
        self.onDone = onDone
        _date = State(initialValue: existing?.date ?? Date())
        _text = State(initialValue: existing?.body ?? "")
        _existingPhotos = State(initialValue: existing?.photos ?? [])
    }

    private var isEditing: Bool { existing != nil }
    private var trimmedBody: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !trimmedBody.isEmpty || newCount > 0 || !existingPhotos.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Day", selection: $date, in: ...Date(), displayedComponents: .date)
                        .disabled(isEditing)
                }

                Section("Words") {
                    TextField("What happened today?", text: $text, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section("Photos") {
                    if !existingPhotos.isEmpty {
                        photoStrip
                    }
                    PhotosPicker(selection: $picks, maxSelectionCount: 12, matching: .images) {
                        Label(newCount > 0 ? "\(newCount) photo(s) selected" : "Add photos",
                              systemImage: "photo.badge.plus")
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
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? (progress ?? "Saving…") : "Save") { Task { await save() } }
                        .disabled(!canSave || saving)
                }
            }
            .onChange(of: picks) { newPicks in newCount = newPicks.count }
            .interactiveDismissDisabled(saving)
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(existingPhotos) { item in
                    RemoteImage(path: item.thumbUrl)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            if item.uploaderId == existing?.authorId {
                                Button { Task { await removeExisting(item) } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                }
                                .padding(3)
                            }
                        }
                }
            }
            .padding(.vertical, 2)
        }
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
            let entry = try await APIClient.shared.createJournalEntry(date: isoDay(date), body: trimmedBody)
            let total = picks.count
            for (i, pick) in picks.enumerated() {
                if total > 1 { progress = "Photo \(i + 1)/\(total)" }
                guard let data = try await pick.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data),
                      let jpeg = ui.jpegData(compressionQuality: 0.85) else { continue }
                _ = try await APIClient.shared.uploadJournalPhoto(entryId: entry.id, jpeg)
            }
            Haptics.success()
            await onDone()
            dismiss()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}
