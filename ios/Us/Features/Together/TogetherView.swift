import SwiftUI

struct TogetherView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.softBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        NavigationLink { DailyQuestionView() } label: {
                            activityCard(emoji: "💭", title: "Daily Question",
                                         subtitle: "Answer today's question together")
                        }
                        NavigationLink { TicTacToeView() } label: {
                            activityCard(emoji: "🎮", title: "Tic-Tac-Toe",
                                         subtitle: "Play a round with your partner")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Together")
        }
    }

    private func activityCard(emoji: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Text(emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
