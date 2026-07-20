import SwiftUI

/// The Us. Premium paywall. Shown whenever someone taps a locked quiz pack or
/// game: an animated iPhone playing through what's behind the lock, the perks,
/// and one €2.99/month button.
struct PaywallView: View {
    /// What the user just tapped, so the headline can speak to it.
    var trigger: PaywallTrigger = .general

    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 26) {
                    header
                    PaywallPhone()
                    perks
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 240)
            }
            .scrollIndicators(.hidden)

            VStack { Spacer(); purchaseBar }
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .task { await premium.loadProduct() }
        .onChange(of: premium.isPremium) { unlocked in
            if unlocked {
                Haptics.success()
                dismiss()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("US. PREMIUM")
                .font(.caption.bold()).tracking(2.5)
                .foregroundStyle(Theme.rose)

            Text(trigger.headline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("One subscription for both of you — every quiz pack, every game, no limits.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    // MARK: Perks

    private var perks: some View {
        VStack(spacing: 12) {
            perk("square.grid.2x2.fill", "purple", "All 12 quiz packs",
                 "Sex & Love, Money, Travel, Family, Values and more — beyond the two free ones.")
            perk("gamecontroller.fill", "pink", "Every game unlocked",
                 "Couples Debate, Draw Together and Snap Hunt, plus everything we add next.")
            perk("infinity", "blue", "No limits",
                 "Unlimited photos in your gallery and journal, and the full storage quota.")
            perk("heart.fill", "green", "Covers you both",
                 "One subscription unlocks Premium for you and your partner.")
        }
    }

    private func perk(_ icon: String, _ colorKey: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            QuizIconTile(systemName: icon, colorKey: colorKey, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Theme.ink)
                Text(body).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
    }

    // MARK: Purchase

    private var purchaseBar: some View {
        VStack(spacing: 12) {
            if let error = premium.errorMessage {
                Text(error)
                    .font(.footnote).foregroundStyle(Theme.coral)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await premium.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if premium.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Unlock everything · \(premium.priceLine)")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(premium.isPurchasing)

            Text("Auto-renews monthly. Cancel anytime in the App Store.")
                .font(.caption2).foregroundStyle(.secondary)

            HStack(spacing: 18) {
                Button("Restore") { Task { await premium.restore() } }
                    .disabled(premium.isRestoring)
                Link("Terms", destination: URL(string: "https://usapp.love/terms")!)
                Link("Privacy", destination: URL(string: "https://usapp.love/privacy")!)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Theme.peach.opacity(0), Theme.peach.opacity(0.55), Theme.peach.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.regularMaterial, in: Circle())
        }
        .padding(.trailing, 18)
        .padding(.top, 12)
        .accessibilityLabel("Close")
    }
}

/// Where the paywall was opened from — only changes the headline.
enum PaywallTrigger {
    case general
    case quizCategory(String)
    case game(String)

    var headline: String {
        switch self {
        case .general:
            return "Unlock everything"
        case .quizCategory(let title):
            return "Unlock \(title) and every other pack"
        case .game(let title):
            return "Unlock \(title) and every other game"
        }
    }
}

// MARK: - Lock badge used on locked cards

/// The little padlock pill stamped on locked quiz packs and game cards.
struct PremiumLockBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill").font(.system(size: compact ? 9 : 10, weight: .bold))
            if !compact { Text("PREMIUM").font(.system(size: 10, weight: .bold)).tracking(0.5) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 5 : 5)
        .background(Theme.warmGradient, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }
}

// MARK: - Presenting the paywall

extension View {
    /// Attaches the paywall sheet to a view.
    func paywall(isPresented: Binding<Bool>, trigger: PaywallTrigger = .general) -> some View {
        sheet(isPresented: isPresented) {
            PaywallView(trigger: trigger)
        }
    }
}
