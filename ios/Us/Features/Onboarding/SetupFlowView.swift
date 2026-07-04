import SwiftUI

/// Shown once after pairing, on BOTH partners' devices:
/// 1. pick the partner's pronoun (personalises copy + widget),
/// 2. set how long you've been together (drives the "Been together" widget).
struct SetupFlowView: View {
    @EnvironmentObject var session: Session
    @Binding var isPresented: Bool

    @State private var step: Step = .pronoun
    @State private var selectedPronoun: PartnerPronoun?
    @State private var startDate = Date()
    @State private var saving = false

    enum Step { case pronoun, startDate }

    /// Needs to run if the pronoun hasn't been chosen or the couple has no start date.
    static func isNeeded(session: Session) -> Bool {
        !session.hasChosenPronoun || session.couple?.startDate == nil
    }

    var body: some View {
        ZStack {
            Theme.warmGradient.ignoresSafeArea()
            switch step {
            case .pronoun: pronounStep
            case .startDate: startDateStep
            }
        }
        .onAppear {
            step = session.hasChosenPronoun ? .startDate : .pronoun
            if let existing = session.couple?.startDate { startDate = existing }
        }
    }

    private var partnerName: String { session.partner?.displayName ?? "your partner" }

    // MARK: - Step 1 · Pronoun

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
                ForEach(PartnerPronoun.allCases) { pronounOption($0) }
            }

            Spacer()

            Button {
                if let selectedPronoun { session.setPartnerPronoun(selectedPronoun) }
                withAnimation { step = .startDate }
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

    // MARK: - Step 2 · Start date

    private var startDateStep: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 16)
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 50)).foregroundStyle(.white)
            VStack(spacing: 6) {
                Text("How long have you been together?")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Pick the day it all began.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
            }

            DatePicker("", selection: $startDate,
                       in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.rose)
                .padding(8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("\(daysTogether) days together 💜")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer(minLength: 12)

            Button { Task { await finish() } } label: {
                if saving { ProgressView().tint(.white) } else { Text("Finish") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(saving)
        }
        .padding(24)
    }

    private var daysTogether: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day],
                                         from: cal.startOfDay(for: startDate),
                                         to: cal.startOfDay(for: Date())).day ?? 0)
    }

    private func finish() async {
        saving = true
        await session.saveStartDate(startDate)
        saving = false
        withAnimation { isPresented = false }
    }
}
