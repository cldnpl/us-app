import SwiftUI
import UIKit

/// Shared visual language for Us. — warm blush→coral→peach gradients, rounded cards.
///
/// The brand hues (blush/coral/peach/rose) are fixed: they are the identity, and
/// they read fine against both a light and a dark backdrop. Anything used as
/// *text* or as a *surface* adapts to the colour scheme instead, because those
/// are the pairings that decide legibility.
enum Theme {
    static let blush = Color(red: 1.0, green: 0.71, blue: 0.76)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let peach = Color(red: 1.0, green: 0.85, blue: 0.73)

    /// Primary text colour. Near-black on light, warm off-white on dark — it is
    /// drawn on `.regularMaterial` cards and on `softBackground`, both of which
    /// invert with the colour scheme, so a fixed near-black would disappear.
    static let ink = Color(dynamic: UIColor(red: 0.18, green: 0.16, blue: 0.20, alpha: 1),
                           dark: UIColor(red: 0.96, green: 0.94, blue: 0.95, alpha: 1))

    /// Brand rose used across the app (chrome, hero, accents). This is the soft
    /// warm pink sampled straight from the app icon's gradient (its mid-tone),
    /// so the whole app matches the icon instead of the old darker magenta.
    static let rose = Color(red: 1.0, green: 0.55, blue: 0.57)

    /// Translucent plate for pills and tiles that sit on `softBackground`.
    /// Replaces hardcoded `.white.opacity(…)`, which turned into a bright hole
    /// in dark mode.
    static let surface = Color(dynamic: UIColor.white.withAlphaComponent(0.55),
                               dark: UIColor.white.withAlphaComponent(0.10))

    /// Hairline rim used on cards/tiles. White-ish on light, barely-there on dark.
    static let hairline = Color(dynamic: UIColor.white.withAlphaComponent(0.35),
                                dark: UIColor.white.withAlphaComponent(0.12))

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

    /// Full-screen app backdrop. In light mode it's the warm peach/blush wash;
    /// in dark mode it's a deep warm plum, so it still reads as *ours* without
    /// washing out to muddy maroon over black.
    static var softBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(dynamic: UIColor(red: 1.0, green: 0.85, blue: 0.73, alpha: 0.35),
                      dark: UIColor(red: 0.13, green: 0.09, blue: 0.13, alpha: 1.0)),
                Color(dynamic: UIColor(red: 1.0, green: 0.71, blue: 0.76, alpha: 0.25),
                      dark: UIColor(red: 0.09, green: 0.07, blue: 0.10, alpha: 1.0)),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    /// Builds a colour that resolves differently in light and dark mode.
    init(dynamic light: UIColor, dark: UIColor) {
        self.init(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// The app wordmark shown on the left of the navigation bar. Uses the brand
/// rose so it reads on the native (glass/translucent) navigation bar.
struct BrandLogo: View {
    var color: Color = Theme.rose
    var body: some View {
        Image("UsLogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: 30)
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
