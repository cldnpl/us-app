import SwiftUI
import UIKit

/// In-memory cache for fetched images (NSCache is thread-safe).
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
    func remove(for key: String) { cache.removeObject(forKey: key as NSString) }
}

extension Notification.Name {
    /// Posted when a specific image path's cached bytes are no longer valid
    /// (e.g. after re-uploading an avatar to the same URL). `userInfo["path"]`
    /// carries the invalidated path; RemoteImages that display it reload.
    static let imageCacheInvalidated = Notification.Name("us.imageCacheInvalidated")
}

/// Loads an image from an authenticated API path (AsyncImage can't send the
/// Bearer header), with caching.
struct RemoteImage: View {
    let path: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    /// Bumped when an `imageCacheInvalidated` notification for this exact path
    /// arrives, so the `.task(id:)` below re-fires and the fresh bytes are
    /// fetched. The server can't always version the URL (e.g. the avatar path
    /// is stable), so we invalidate explicitly on writes that replace bytes
    /// under the same key.
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if let image {
                // Draw/snap submissions must never inherit template or tint
                // rendering from a dark comparison screen.
                Image(uiImage: image.withRenderingMode(.alwaysOriginal))
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .task(id: "\(path)#\(reloadToken)") { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .imageCacheInvalidated)) { note in
            if let invalidated = note.userInfo?["path"] as? String, invalidated == path {
                reloadToken &+= 1
            }
        }
    }

    private func load() async {
        if let cached = ImageCache.shared.image(for: path) {
            image = cached
            return
        }
        guard let data = try? await APIClient.shared.imageData(relativePath: path),
              let ui = UIImage(data: data) else { return }
        ImageCache.shared.set(ui, for: path)
        image = ui
    }
}
