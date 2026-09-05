import SwiftUI

/// Apple Health identification, shown wherever cycle data appears.
///
/// App Review (guideline 2.5.1) requires an app that uses HealthKit to say so
/// plainly in its own interface, so these views are deliberately explicit about
/// what Us reads, what it never does, and where the user controls it — and they
/// are shown on every path through the cycle feature, including the supporter
/// path where no HealthKit data is read at all.
enum AppleHealth {
    /// Deep link to the Health app. Health ships with iOS and cannot be removed.
    static let appURL = URL(string: "x-apple-health://")!

    static let readsLine = "Us reads your menstrual cycle data from Apple Health, with your permission."
    /// Says plainly that the cycle can come from whichever app she already uses,
    /// as long as it syncs to Health — that's the whole point of reading Health
    /// rather than asking her to type her periods in again.
    static let otherAppsLine = "It works with whatever you already track your period in — Health itself, or apps like Flo or Clue that sync to it."
    static let neverWritesLine = "Us never writes to Apple Health and never uploads your health data. Your cycle is calculated on this iPhone."
    static let manageLine = "You can review or revoke access anytime in Health ▸ Sharing ▸ Apps, or in Settings ▸ Privacy & Security ▸ Health ▸ Us."
}

/// Full card identifying the Apple Health integration, with the connect action
/// when the user hasn't granted access yet.
struct AppleHealthCard: View {
    /// True once Health has been connected on this iPhone (remembered across
    /// relaunches and sign-outs), not merely while we happen to hold data.
    let isConnected: Bool
    /// Overrides the status line, e.g. "Connected — waiting for period data".
    var statusDetail: String?
    var isBusy: Bool = false
    var onConnect: (() -> Void)?
    /// Re-reads Health on demand, for when a tracking app has just synced.
    var onRefresh: (() async -> Void)?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.rose)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc: "Apple Health").font(.headline)
                        Text(statusDetail ?? (isConnected ? "Connected — your cycle is read from Health"
                                                          : "Not connected"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Connected")
                    }
                }

                Text(AppleHealth.readsLine)
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(AppleHealth.otherAppsLine)
                    .font(.footnote).foregroundStyle(.secondary)
                Text(AppleHealth.neverWritesLine)
                    .font(.footnote).foregroundStyle(.secondary)

                if let onConnect, !isConnected {
                    Button(action: onConnect) {
                        if isBusy { ProgressView().tint(.white).frame(maxWidth: .infinity) }
                        else { Label(loc: "Connect Apple Health", systemImage: "heart.text.square.fill") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isBusy)
                }

                if let onRefresh {
                    Button {
                        Task { await onRefresh() }
                    } label: {
                        if isBusy { ProgressView().frame(maxWidth: .infinity) }
                        else { Label(loc: "Check Health again", systemImage: "arrow.clockwise") }
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.rose)
                    .disabled(isBusy)
                }

                Link(destination: AppleHealth.appURL) {
                    Label(loc: "Open the Health app", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Theme.rose)

                Text(AppleHealth.manageLine)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Compact one-line identification of the Apple Health integration: icon, name,
/// connection status, chevron. Tapping opens `AppleHealthDetailView` with the
/// full explanation.
///
/// This is what the cycle screen shows once tracking is running. Guideline 2.5.1
/// only asks that the HealthKit usage be identified in the interface and that
/// the user can reach the details — it doesn't ask for half a screen of copy
/// above the fold on every visit.
struct AppleHealthRow: View {
    let isConnected: Bool
    /// Overrides the status line, e.g. "Waiting for period data".
    var statusDetail: String?
    /// Re-reads Health from the detail screen, for a tracking app that just synced.
    var onRefresh: (() async -> Void)?

    var body: some View {
        NavigationLink {
            AppleHealthDetailView(isConnected: isConnected, onRefresh: onRefresh)
        } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.rose)
                        .frame(width: 28)
                    Text(loc: "Apple Health").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(statusDetail ?? (isConnected ? "Connected" : "Not connected"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.footnote).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// The full Apple Health explanation, on its own screen so the cycle screen can
/// stay about the cycle. Reached from `AppleHealthRow`.
struct AppleHealthDetailView: View {
    let isConnected: Bool
    var onRefresh: (() async -> Void)?
    @State private var isBusy = false

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            ScrollView {
                AppleHealthCard(isConnected: isConnected, isBusy: isBusy, onRefresh: refresh)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
        }
        .navigationTitle(Text(loc: "Apple Health"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var refresh: (() async -> Void)? {
        guard let onRefresh else { return nil }
        return {
            isBusy = true
            await onRefresh()
            isBusy = false
        }
    }
}

/// One-line "where this comes from" note, for screens that show cycle numbers.
struct AppleHealthSourceNote: View {
    var text = "Cycle data comes from Apple Health on this iPhone."

    var body: some View {
        Label(text, systemImage: "heart.text.square.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// A small, unmistakable "Apple Health" pill — the Health-app-red heart glyph
/// plus the words "Apple Health". Placed at the top of every cycle-related card
/// so anyone (including App Review) sees at a glance that the feature is
/// powered by HealthKit, without having to open the screen.
struct AppleHealthBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.text.square.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Text(loc: "Apple Health")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.red.opacity(0.10), in: Capsule())
        .accessibilityLabel("Powered by Apple Health")
    }
}
