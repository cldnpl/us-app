import SwiftUI
import PencilKit

// MARK: - Entry

struct DrawTogetherView: View {
    @EnvironmentObject var session: Session
    @State private var round: DrawRound?
    @State private var errorMessage: String?

    private var partnerName: String { session.partner?.displayName ?? "your partner" }
    private var accent: Color { QuizPalette.accent("purple") }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let round {
                if round.mySubmitted {
                    revealScreen(round)
                } else {
                    DrawingPad(prompt: round.prompt) { data in await submit(data) }
                }
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Draw Together")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: reveal / waiting

    @ViewBuilder
    private func revealScreen(_ round: DrawRound) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("“\(round.prompt)”")
                    .font(.title3.bold()).multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink).padding(.top, 8)

                if round.revealed {
                    Text("The big reveal! 🎨").font(.headline).foregroundStyle(accent)
                    drawingCard(title: "You", path: round.myImagePath)
                    drawingCard(title: partnerName, path: round.partnerImagePath)
                } else {
                    VStack(spacing: 12) {
                        QuizIconTile(systemName: "hourglass", colorKey: "purple", size: 64).padding(.top, 8)
                        Text("Nicely done!").font(.title3.bold()).foregroundStyle(Theme.ink)
                        Text("Your drawing is locked in. You'll both see them side by side once \(partnerName) draws too.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    drawingCard(title: "Your drawing", path: round.myImagePath)
                }

                VStack(spacing: 10) {
                    Button { Task { await newRound() } } label: {
                        Label("New drawing", systemImage: "arrow.clockwise")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(PillButtonStyle(color: accent))

                    if !round.revealed {
                        Button { Task { await reload() } } label: {
                            Label("Check again", systemImage: "arrow.triangle.2.circlepath").font(.footnote.bold())
                        }
                        .foregroundStyle(accent)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func drawingCard(title: String, path: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Group {
                if let path {
                    RemoteImage(path: path, contentMode: .fit)
                } else {
                    Rectangle().fill(.quaternary).overlay(ProgressView())
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient("purple").opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: actions

    private func load() async {
        do { round = try await APIClient.shared.getDraw() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }

    private func reload() async { round = try? await APIClient.shared.getDraw() }

    private func submit(_ data: Data) async {
        do {
            round = try await APIClient.shared.submitDraw(data)
            Haptics.success()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func newRound() async {
        do {
            round = try await APIClient.shared.newDrawRound()
            Haptics.tap(.light)
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}

// MARK: - Drawing pad

struct DrawingPad: View {
    let prompt: String
    var onSubmit: (Data) async -> Void

    @State private var canvas = PKCanvasView()
    @State private var color: Color = .black
    @State private var isEraser = false
    @State private var remaining = 180
    @State private var submitting = false

    private let total = 180
    private let palette: [Color] = [.black, .red, .orange, .green, .blue, .purple]
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var accent: Color { QuizPalette.accent("purple") }

    private var tool: PKTool {
        isEraser ? PKEraserTool(.vector) : PKInkingTool(.pen, color: UIColor(color), width: 6)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            PencilCanvas(canvas: $canvas, tool: tool)
                .background(.white)
                .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(.black.opacity(0.05)))
            toolbar
        }
        .onReceive(timer) { _ in
            guard !submitting else { return }
            if remaining > 0 { remaining -= 1 }
            if remaining == 0 { doSubmit() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("DRAW").font(.caption2.bold()).tracking(2).foregroundStyle(accent)
            Text("“\(prompt)”")
                .font(.title3.bold()).multilineTextAlignment(.center)
                .foregroundStyle(Theme.ink).padding(.horizontal, 20)
            HStack(spacing: 6) {
                Image(systemName: "clock.fill").font(.caption2)
                Text(timeString).font(.subheadline.bold().monospacedDigit())
            }
            .foregroundStyle(remaining <= 15 ? Theme.coral : .secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private var toolbar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ForEach(palette, id: \.self) { c in
                    Button {
                        color = c; isEraser = false; Haptics.tap(.light)
                    } label: {
                        Circle().fill(c)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(.white, lineWidth: (!isEraser && color == c) ? 3 : 0))
                            .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 1))
                    }
                }
                Spacer()
                Button { isEraser = true; Haptics.tap(.light) } label: {
                    Image(systemName: "eraser.fill")
                        .foregroundStyle(isEraser ? .white : Theme.ink)
                        .padding(8)
                        .background(isEraser ? accent : Color(.secondarySystemBackground), in: Circle())
                }
                Button { canvas.undoManager?.undo() } label: {
                    Image(systemName: "arrow.uturn.backward").foregroundStyle(Theme.ink)
                        .padding(8).background(Color(.secondarySystemBackground), in: Circle())
                }
                Button { canvas.drawing = PKDrawing() } label: {
                    Image(systemName: "trash").foregroundStyle(Theme.ink)
                        .padding(8).background(Color(.secondarySystemBackground), in: Circle())
                }
            }

            Button { doSubmit() } label: {
                if submitting { ProgressView() }
                else { Label("Done", systemImage: "checkmark").font(.subheadline.bold()) }
            }
            .buttonStyle(PillButtonStyle(color: accent))
            .frame(maxWidth: .infinity)
            .disabled(submitting)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.thinMaterial)
    }

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private func doSubmit() {
        guard !submitting, let data = exportDrawing() else { return }
        submitting = true
        Task { await onSubmit(data); submitting = false }
    }

    private func exportDrawing() -> Data? {
        let bounds = canvas.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let scale = UIScreen.main.scale
        let strokes = canvas.drawing.image(from: bounds, scale: scale)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let composed = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            strokes.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        return composed.jpegData(compressionQuality: 0.9)
    }
}

// MARK: - Canvas bridge

struct PencilCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var tool: PKTool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.tool = tool
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = tool
    }
}
