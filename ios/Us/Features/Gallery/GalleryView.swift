import SwiftUI
import PhotosUI

struct GalleryView: View {
    @EnvironmentObject var session: Session

    @State private var items: [MediaItem] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var uploadDone = 0
    @State private var uploadTotal = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: MediaItem?

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                } else if items.isEmpty {
                    emptyState
                } else {
                    PhotoScatterView(
                        items: items,
                        onTap: { selected = $0 },
                        onDelete: { item in Task { await delete(item) } }
                    )
                }
            }
            .navigationTitle("Photos")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 12, matching: .images) {
                        if isUploading {
                            HStack(spacing: 6) {
                                ProgressView()
                                if uploadTotal > 1 { Text("\(uploadDone)/\(uploadTotal)").font(.caption) }
                            }
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .disabled(isUploading)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: pickerItems) { picks in
                Task { await uploadMany(picks) }
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52)).foregroundStyle(Theme.coral)
            Text("No photos yet").font(.title3.bold())
            Text("Tap ＋ to toss in a few photos.")
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

    private func uploadMany(_ picks: [PhotosPickerItem]) async {
        guard !picks.isEmpty else { return }
        isUploading = true
        errorMessage = nil
        uploadTotal = picks.count
        uploadDone = 0
        defer { isUploading = false; pickerItems = []; uploadTotal = 0; uploadDone = 0 }

        for pick in picks {
            do {
                guard let data = try await pick.loadTransferable(type: Data.self),
                      let ui = UIImage(data: data),
                      let jpeg = ui.jpegData(compressionQuality: 0.85) else { continue }
                _ = try await APIClient.shared.uploadPhoto(jpeg, caption: nil)
                uploadDone += 1
            } catch {
                errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
            }
        }
        await load()
        if uploadDone > 0 { Haptics.success() }
    }

    private func delete(_ item: MediaItem) async {
        do {
            try await APIClient.shared.deletePhoto(id: item.id)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                items.removeAll { $0.id == item.id }
            }
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}

/// A playful "photos tossed on a table" layout: each photo is rotated and
/// offset by a stable pseudo-random amount (derived from its id), overlapping
/// the ones below it, with the newest on top.
private struct PhotoScatterView: View {
    let items: [MediaItem]
    let onTap: (MediaItem) -> Void
    let onDelete: (MediaItem) -> Void

    private let cardW: CGFloat = 220
    private let cardH: CGFloat = 292
    private let step: CGFloat = 168 // vertical advance per photo (overlap = cardH - step)

    var body: some View {
        GeometryReader { geo in
            let jitter = max(6, (geo.size.width - cardW) / 2 - 14)
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .top) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        card(item)
                            .rotationEffect(.degrees(angle(item)))
                            .offset(x: dx(item, jitter),
                                    y: CGFloat(idx) * step + 36 + CGFloat(rand(item.id, 3) * 20))
                            .zIndex(Double(items.count - idx))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: CGFloat(max(items.count - 1, 0)) * step + cardH + 90, alignment: .top)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: items.count)
            }
        }
    }

    private func card(_ item: MediaItem) -> some View {
        RemoteImage(path: item.thumbUrl)
            .frame(width: cardW, height: cardH)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white, lineWidth: 6)
            )
            .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .onTapGesture { onTap(item) }
            .contextMenu {
                Button(role: .destructive) { onDelete(item) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    // Stable pseudo-random in 0..1 from the item id (FNV-1a), so angles/offsets
    // don't jump on every re-render.
    private func rand(_ id: String, _ salt: UInt64) -> Double {
        var h: UInt64 = 1469598103934665603
        for b in id.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        h = (h ^ salt) &* 1099511628211
        return Double(h % 10_000) / 10_000.0
    }

    private func angle(_ item: MediaItem) -> Double { (rand(item.id, 1) * 2 - 1) * 13 }
    private func dx(_ item: MediaItem, _ jitter: CGFloat) -> CGFloat {
        CGFloat(rand(item.id, 2) * 2 - 1) * jitter
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
