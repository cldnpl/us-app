import SwiftUI

/// One of the couple games shown in the Games section.
struct GameDef: Identifiable {
    enum Kind { case hwdykm, debate, draw, snap, comingSoon }
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let colorKey: String
    let badge: String?          // "MOST PLAYED"
    let cta: String
    let kind: Kind

    static let all: [GameDef] = [
        GameDef(id: "hwdykm", title: "How Well Do You Know Me",
                subtitle: "Both lock in your answers privately, reveal at the same time, and see your compatibility score — 14 packs from cute to spicy.",
                icon: "questionmark.circle.fill", colorKey: "pink", badge: "MOST PLAYED",
                cta: "Start the quiz", kind: .hwdykm),
        GameDef(id: "debate", title: "Couples Debate",
                subtitle: "Pick a topic pack, get assigned for or against, then make your case — an AI judge scores each round and crowns a winner.",
                icon: "bubble.left.and.bubble.right.fill", colorKey: "blue", badge: nil,
                cta: "Start a debate", kind: .debate),
        GameDef(id: "draw", title: "Draw Together",
                subtitle: "Get the same prompt, draw it on your own half of a split canvas, and reveal both when the timer's up — no scores, just yours.",
                icon: "pencil.tip.crop.circle", colorKey: "purple", badge: nil,
                cta: "Start drawing", kind: .draw),
        GameDef(id: "snap", title: "Snap Hunt",
                subtitle: "The app calls a loose clue, you both race around the house to find it, snap a photo — and a judge crowns the cleverest find.",
                icon: "camera.viewfinder", colorKey: "green", badge: nil,
                cta: "Start a hunt", kind: .snap),
    ]
}

/// getangie-style game card: icon tile, title + badge, description, CTA.
struct GameCard: View {
    let game: GameDef

    var body: some View {
        let accent = QuizPalette.accent(game.colorKey)
        VStack(alignment: .leading, spacing: 14) {
            QuizIconTile(systemName: game.icon, colorKey: game.colorKey, size: 52)

            HStack(spacing: 8) {
                Text(game.title).font(.title3.bold()).foregroundStyle(Theme.ink)
                if let badge = game.badge {
                    Text(badge)
                        .font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.warmGradient, in: Capsule())
                }
            }
            Text(game.subtitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text(game.cta).font(.subheadline.bold()).foregroundStyle(accent)
                Image(systemName: game.kind == .comingSoon ? "clock.fill" : "play.fill")
                    .font(.caption2).foregroundStyle(accent)
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

/// Placeholder for games that need camera/drawing/AI infra — shows what's coming.
struct ComingSoonGameView: View {
    let game: GameDef

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                QuizIconTile(systemName: game.icon, colorKey: game.colorKey, size: 84)
                Text(game.title).font(.title.bold()).foregroundStyle(Theme.ink)
                Text("COMING SOON").font(.caption.bold()).tracking(2)
                    .foregroundStyle(QuizPalette.accent(game.colorKey))
                Text(game.subtitle)
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
                Text("We're building this one to work at your own pace — play now, your partner catches up whenever.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40).padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
