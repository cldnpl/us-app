import SwiftUI

struct TicTacToeView: View {
    @EnvironmentObject var session: Session
    @State private var game: Game?
    @State private var errorMessage: String?

    private let poll = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            VStack(spacing: 28) {
                statusText
                board
                if game?.status == "finished" {
                    Button("New game") { Task { await newGame() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 40)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
        .navigationTitle("Tic-Tac-Toe")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onReceive(poll) { _ in
            // Keep in sync with the partner while it isn't our turn.
            if !myTurn { Task { await load() } }
        }
    }

    private var mySymbol: String {
        guard let g = game, let me = session.user?.id else { return "" }
        return g.state.x == me ? "X" : "O"
    }

    private var myTurn: Bool {
        game?.status == "active" && game?.turnUserId == session.user?.id
    }

    @ViewBuilder private var statusText: some View {
        if let g = game {
            if g.status == "finished" {
                switch g.state.winner {
                case "draw": Text("It's a draw 🤝").font(.title2.bold())
                case mySymbol: Text("You won! 🎉").font(.title2.bold()).foregroundStyle(Theme.coral)
                default: Text("\(session.partner?.displayName ?? "Your partner") won 💛").font(.title2.bold())
                }
            } else if myTurn {
                Text("Your turn  (\(mySymbol))").font(.title2.bold())
            } else {
                Text("\(session.partner?.displayName ?? "Partner")'s turn…").font(.title2.bold()).foregroundStyle(.secondary)
            }
        } else {
            ProgressView()
        }
    }

    private var board: some View {
        let cells = game?.state.board ?? Array(repeating: "", count: 9)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<9, id: \.self) { i in
                Button {
                    Task { await move(i) }
                } label: {
                    Text(cells[i])
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .foregroundStyle(cells[i] == "X" ? Theme.coral : Color.blue)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!myTurn || cells[i] != "")
            }
        }
        .frame(maxWidth: 340)
    }

    private func load() async {
        do { game = try await APIClient.shared.getGame("tictactoe") }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }

    private func move(_ index: Int) async {
        do {
            game = try await APIClient.shared.gameMove("tictactoe", index: index)
            Haptics.tap()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func newGame() async {
        do { game = try await APIClient.shared.newGame("tictactoe"); errorMessage = nil }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }
}
