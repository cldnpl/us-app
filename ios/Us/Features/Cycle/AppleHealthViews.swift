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
    static let neverWritesLine = "Us never writes to Apple Health and never uploads your health data. Your cycle is calculated on this iPhone."
    static let manageLine = "You can review or revoke access anytime in Health ▸ Sharing ▸ Apps, or in Settings ▸ Privacy & Security ▸ Health ▸ Us."
}

/// Full card identifying the Apple Health integration, with the connect action
/// when the user hasn't granted access yet.
struct AppleHealthCard: View {
    /// True once we have cycle insights derived from Health data.
    let isConnected: Bool
    var isBusy: Bool = false
    var onConnect: (() -> Void)?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.rose)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health").font(.headline)
                        Text(isConnected ? "Connected — your cycle is read from Health"
                                         : "Not connected")
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
                Text(AppleHealth.neverWritesLine)
                    .font(.footnote).foregroundStyle(.secondary)

                if let onConnect, !isConnected {
                    Button(action: onConnect) {
                        if isBusy { ProgressView().tint(.white).frame(maxWidth: .infinity) }
                        else { Label("Connect Apple Health", systemImage: "heart.text.square.fill") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isBusy)
                }

                Link(destination: AppleHealth.appURL) {
                    Label("Open the Health app", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Theme.rose)

                Text(AppleHealth.manageLine)
                    .font(.caption).foregroundStyle(.secondary)
            }
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
