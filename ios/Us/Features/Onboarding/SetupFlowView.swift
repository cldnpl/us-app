import SwiftUI

/// Shown once after pairing: pick the partner's pronoun, which personalises
/// copy ("thinking of her / him / them") and the widget.
struct SetupFlowView: View {
    @EnvironmentObject var session: Session
    @Binding var isPresented: Bool

    @State private var selectedPronoun: PartnerPronoun?

    /// Whether the flow needs to run at all.
    static func isNeeded(session: Session) -> Bool {
        !session.hasChosenPronoun
    }

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()
            pronounStep
        }
    }

    private var partnerName: String { session.partner?.displayName ?? "your partner" }

    private var pronounStep: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 52)).foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("A little about \(partnerName)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("How should we refer to \(partnerName)? We'll use it in little messages like “thinking of them”.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 12) {
                ForEach(PartnerPronoun.allCases) { pronoun in
                    pronounOption(pronoun)
                }
            }

            Spacer()

            Button {
                if let selectedPronoun { session.setPartnerPronoun(selectedPronoun) }
                withAnimation { isPresented = false }
            } label: { Text("Continue") }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedPronoun == nil)
                .opacity(selectedPronoun == nil ? 0.6 : 1)
        }
        .padding(28)
    }

    private func pronounOption(_ pronoun: PartnerPronoun) -> some View {
        let isSelected = selectedPronoun == pronoun
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { selectedPronoun = pronoun }
            Haptics.tap(.light)
        } label: {
            HStack {
                Text(pronoun.label)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Theme.rose : .white)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.rose : .white.opacity(0.7))
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(isSelected ? Color.white : Color.white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
