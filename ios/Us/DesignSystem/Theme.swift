import SwiftUI

/// Shared visual language for Us. — warm blush→coral→peach gradients, rounded cards.
enum Theme {
    static let blush = Color(red: 1.0, green: 0.71, blue: 0.76)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let peach = Color(red: 1.0, green: 0.85, blue: 0.73)
    static let ink = Color(red: 0.18, green: 0.16, blue: 0.20)

    /// Brand rose used across the app (chrome, hero, accents). This is the soft
    /// warm pink sampled straight from the app icon's gradient (its mid-tone),
    /// so the whole app matches the icon instead of the old darker magenta.
    static let rose = Color(red: 1.0, green: 0.55, blue: 0.57)

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [blush, coral.opacity(0.85), peach],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Rose gradient for the hero "miss you" button (matches the chrome).
    static var roseGradient: LinearGradient {
        LinearGradient(
            colors: [rose, rose.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var softBackground: LinearGradient {
        LinearGradient(
            colors: [peach.opacity(0.35), blush.opacity(0.25)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The app wordmark shown on the left of the navigation bar. Uses the brand
/// rose so it reads on the native (glass/translucent) navigation bar.
struct BrandLogo: View {
    var color: Color = Theme.rose
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .bold))
            Text("Us.")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(color)
        .fixedSize()
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Us.")
    }
}

/// A rounded, subtly shadowed card container.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

/// Prominent primary button used across onboarding and actions.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.coral, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
