import SwiftUI
import PhotosUI

struct GalleryView: View {
    @EnvironmentObject var session: Session

    @State private var items: [MediaItem] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: MediaItem?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(items) { item in
                                RemoteImage(path: item.thumbUrl)
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .onTapGesture { selected = item }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await delete(item) }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(2)
                    }
                }
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if isUploading { ProgressView() } else { Image(systemName: "plus.circle.fill") }
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: pickerItem) { newItem in
                Task { await upload(newItem) }
            }
            .fullScreenCover(item: $selected) { PhotoDetailView(item: $0) }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.red.opacity(0.9), in: Capsule())
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52)).foregroundStyle(Theme.coral)
            Text("No photos yet").font(.title3.bold())
            Text("Tap ＋ to add your first shared photo.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private func load() async {
        do {
            items = try await APIClient.shared.listMedia().media
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
        isLoading = false
    }

    private func upload(_ picked: PhotosPickerItem?) async {
        guard let picked else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false; pickerItem = nil }
        do {
            guard let data = try await picked.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data),
                  let jpeg = ui.jpegData(compressionQuality: 0.85) else {
                errorMessage = "Couldn't read that photo"
                return
            }
            let item = try await APIClient.shared.uploadPhoto(jpeg, caption: nil)
            items.insert(item, at: 0)
            Haptics.success()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func delete(_ item: MediaItem) async {
        do {
            try await APIClient.shared.deletePhoto(id: item.id)
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}

struct PhotoDetailView: View {
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RemoteImage(path: item.fileUrl, contentMode: .fit)
                .ignoresSafeArea()
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()
                Spacer()
                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .foregroundStyle(.white)
                        .padding().frame(maxWidth: .infinity)
                        .background(.black.opacity(0.4))
                }
            }
        }
    }
}
