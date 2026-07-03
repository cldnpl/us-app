import SwiftUI
import UIKit

/// In-memory cache for fetched images (NSCache is thread-safe).
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
}

/// Loads an image from an authenticated API path (AsyncImage can't send the
/// Bearer header), with caching.
struct RemoteImage: View {
    let path: String
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .task(id: path) { await load() }
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
