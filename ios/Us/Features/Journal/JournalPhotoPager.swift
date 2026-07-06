import SwiftUI

/// Fullscreen, swipeable viewer for a day's photos. Own photos can be deleted
/// from here (a photo's uploader is the only one who may remove it).
struct JournalPhotoPager: View {
    let photos: [MediaItem]
    let startIndex: Int
    let onChange: () async -> Void

    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int
    @State private var items: [MediaItem]

    init(photos: [MediaItem], startIndex: Int, onChange: @escaping () async -> Void) {
        self.photos = photos
        self.startIndex = startIndex
        self.onChange = onChange
        _selection = State(initialValue: min(max(startIndex, 0), max(photos.count - 1, 0)))
        _items = State(initialValue: photos)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    RemoteImage(path: item.fileUrl, contentMode: .fit)
                        .ignoresSafeArea()
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .automatic : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title).foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    if canDeleteCurrent {
                        Button(role: .destructive) { Task { await deleteCurrent() } } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title).foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding()
                Spacer()
            }
        }
    }

    private var canDeleteCurrent: Bool {
        guard items.indices.contains(selection) else { return false }
        return items[selection].uploaderId == session.user?.id
    }

    private func deleteCurrent() async {
        guard items.indices.contains(selection) else { return }
        let target = items[selection]
        do {
            try await APIClient.shared.deletePhoto(id: target.id)
            await onChange()
            withAnimation {
                items.removeAll { $0.id == target.id }
                selection = min(selection, max(items.count - 1, 0))
            }
            if items.isEmpty { dismiss() }
        } catch {
            // Non-fatal: leave the viewer open if the delete fails.
        }
    }
}
