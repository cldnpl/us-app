import SwiftUI

/// A circular profile photo. Loads the authenticated avatar image for a user
/// (or partner) from the backend; if none has been set, falls back to the
/// brand heart mark so the placeholder stays warm rather than an empty gray
/// circle.
///
/// Path convention: `/v1/users/{userId}/avatar` — matches the server route.
/// Callers pass the `avatarPath` copied from `User`; nil means no photo.
struct Avatar: View {
    /// URL path returned by the server (e.g. `/v1/users/xxx/avatar`), or nil.
    let path: String?
    /// Optional display name — first letter is used as the ultimate fallback
    /// (only shown briefly while the remote image is loading, if one exists).
    var name: String? = nil
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.rose.opacity(0.18))
            if let path {
                RemoteImage(path: path, contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Theme.rose)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
        .accessibilityLabel(name.map { "\($0) avatar" } ?? "Avatar")
    }
}
