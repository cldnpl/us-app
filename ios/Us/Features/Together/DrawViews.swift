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
                        Text("Waiting for \(partnerName)'s drawing")
                            .font(.title3.bold()).foregroundStyle(Theme.ink)
                        Text("Your drawing is locked in. We'll show both drawings once \(partnerName) finishes.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    drawingCard(title: "Your drawing", path: round.myImagePath)
                }

                VStack(spacing: 10) {
                    if round.revealed {
                        Button { Task { await newRound() } } label: {
                            Label("New drawing", systemImage: "arrow.clockwise")
                                .font(.subheadline.bold())
                        }
                        .buttonStyle(PillButtonStyle(color: accent))
                    }

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

    @State private var canvas = DrawingCanvasView()
    @State private var colorID = "black"
    @State private var brushSize: CGFloat = 6
    @State private var isEraser = false
    @State private var isBucket = false
    @State private var fillImage: UIImage?
    @State private var fillHistory: [UIImage?] = []
    @State private var remaining = 180
    @State private var submitting = false

    private let total = 180
    private let palette = DrawPaletteColor.all
    private let brushSizes: [CGFloat] = [3, 6, 12, 20]
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var accent: Color { QuizPalette.accent("purple") }

    private var tool: PKTool {
        isEraser ? PKEraserTool(.vector) : PKInkingTool(.pen, color: selectedColor.uiColor, width: brushSize)
    }

    private var selectedColor: DrawPaletteColor {
        palette.first(where: { $0.id == colorID }) ?? .black
    }

    var body: some View {
        VStack(spacing: 0) {
            DrawPromptHeader(prompt: prompt, remaining: remaining, accent: accent)
            ZStack {
                Color.white
                if let fillImage {
                    Image(uiImage: fillImage)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                }
                PencilCanvas(canvas: $canvas, tool: tool)
                    .allowsHitTesting(!isBucket)
                if isBucket {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { value in
                            fill(at: value.location)
                        })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .layoutPriority(1)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(.black.opacity(0.05)))
            DrawToolbar(palette: palette, selectedColorID: colorID,
                        brushSize: brushSize, brushSizes: brushSizes,
                        isEraser: isEraser, isBucket: isBucket,
                        accent: accent, submitting: submitting,
                        onColor: { colorID = $0; isEraser = false; isBucket = false; Haptics.tap(.light) },
                        onBrushSize: { brushSize = $0; isEraser = false; isBucket = false; Haptics.tap(.light) },
                        onEraser: { isEraser = true; isBucket = false; Haptics.tap(.light) },
                        onBucket: { isBucket.toggle(); isEraser = false; Haptics.tap(.light) },
                        onUndo: undo,
                        onClear: clear,
                        onDone: { doSubmit() })
        }
        .background(Color.white.ignoresSafeArea(.container, edges: [.leading, .trailing]))
        .onReceive(timer) { _ in
            guard !submitting else { return }
            if remaining > 0 { remaining -= 1 }
            if remaining == 0 { doSubmit() }
        }
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
            fillImage?.draw(in: CGRect(origin: .zero, size: bounds.size))
            strokes.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        return composed.jpegData(compressionQuality: 0.9)
    }

    private func undo() {
        if !fillHistory.isEmpty {
            fillImage = fillHistory.removeLast()
        } else {
            canvas.undoManager?.undo()
        }
    }

    private func clear() {
        canvas.drawing = PKDrawing()
        fillImage = nil
        fillHistory.removeAll()
    }

    private func fill(at point: CGPoint) {
        guard !submitting else { return }
        guard let image = renderedCanvasImage() else { return }
        guard let filled = image.floodFilled(at: point, with: selectedColor.uiColor) else { return }
        fillHistory.append(fillImage)
        fillImage = filled
        isBucket = false
        Haptics.tap(.light)
    }

    private func renderedCanvasImage() -> UIImage? {
        let bounds = canvas.bounds
        guard bounds.width > 1, bounds.height > 1 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: bounds.size))
            fillImage?.draw(in: CGRect(origin: .zero, size: bounds.size))
            canvas.drawing.image(from: bounds, scale: 1).draw(in: CGRect(origin: .zero, size: bounds.size))
        }
    }
}

// MARK: - Pad chrome

/// "DRAW — <prompt>" header with the countdown above the canvas.
struct DrawPromptHeader: View {
    let prompt: String
    let remaining: Int
    let accent: Color

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
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
}

/// Colour palette, brush/fill tools, eraser/undo/clear, and Done.
struct DrawToolbar: View {
    let palette: [DrawPaletteColor]
    let selectedColorID: String
    let brushSize: CGFloat
    let brushSizes: [CGFloat]
    let isEraser: Bool
    let isBucket: Bool
    let accent: Color
    var submitting = false
    var onColor: (String) -> Void = { _ in }
    var onBrushSize: (CGFloat) -> Void = { _ in }
    var onEraser: () -> Void = {}
    var onBucket: () -> Void = {}
    var onUndo: () -> Void = {}
    var onClear: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ForEach(palette) { swatch in
                    Button { onColor(swatch.id) } label: {
                        Circle().fill(swatch.color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().strokeBorder(.white,
                                                            lineWidth: (!isEraser && !isBucket && selectedColorID == swatch.id) ? 3 : 0))
                            .overlay(Circle().strokeBorder(.black.opacity(0.1), lineWidth: 1))
                    }
                    .accessibilityLabel(swatch.name)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Menu {
                    ForEach(brushSizes, id: \.self) { size in
                        Button {
                            onBrushSize(size)
                        } label: {
                            Label("\(Int(size)) pt", systemImage: size == brushSize ? "checkmark" : "circle")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "line.3.horizontal")
                        Text("\(Int(brushSize))")
                            .font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: Capsule())
                }
                .accessibilityLabel("Brush size")

                Button(action: onBucket) {
                    Image(systemName: "paint bucket.fill")
                        .foregroundStyle(isBucket ? .white : Theme.ink)
                        .padding(8)
                        .background(isBucket ? accent : Color(.secondarySystemBackground), in: Circle())
                }
                .accessibilityLabel("Fill area")

                Button(action: onEraser) {
                    Image(systemName: "eraser.fill")
                        .foregroundStyle(isEraser ? .white : Theme.ink)
                        .padding(8)
                        .background(isEraser ? accent : Color(.secondarySystemBackground), in: Circle())
                }
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward").foregroundStyle(Theme.ink)
                        .padding(8).background(Color(.secondarySystemBackground), in: Circle())
                }
                Button(action: onClear) {
                    Image(systemName: "trash").foregroundStyle(Theme.ink)
                        .padding(8).background(Color(.secondarySystemBackground), in: Circle())
                }
            }

            Button(action: onDone) {
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
}

// MARK: - Canvas bridge

struct DrawPaletteColor: Identifiable {
    let id: String
    let name: String
    let color: Color
    let uiColor: UIColor

    static let all: [DrawPaletteColor] = [
        DrawPaletteColor(id: "black", name: "Black", color: Color(red: 0, green: 0, blue: 0), uiColor: .black),
        DrawPaletteColor(id: "red", name: "Red", color: .red, uiColor: .systemRed),
        DrawPaletteColor(id: "orange", name: "Orange", color: .orange, uiColor: .systemOrange),
        DrawPaletteColor(id: "yellow", name: "Yellow", color: .yellow, uiColor: .systemYellow),
        DrawPaletteColor(id: "green", name: "Green", color: .green, uiColor: .systemGreen),
        DrawPaletteColor(id: "blue", name: "Blue", color: .blue, uiColor: .systemBlue),
        DrawPaletteColor(id: "purple", name: "Purple", color: .purple, uiColor: .systemPurple)
    ]

    static let black = DrawPaletteColor(id: "black", name: "Black", color: Color(red: 0, green: 0, blue: 0), uiColor: .black)
}

private extension UIImage {
    /// Flood-fills a contiguous region in a rendered canvas snapshot. The
    /// snapshot includes existing strokes, so the line art remains the fill
    /// boundary while PencilKit continues to own all new brush strokes.
    func floodFilled(at point: CGPoint, with color: UIColor) -> UIImage? {
        guard let cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let x = min(width - 1, max(0, Int(point.x * CGFloat(width) / size.width)))
        let y = min(height - 1, max(0, Int(point.y * CGFloat(height) / size.height)))
        let start = (y * width + x) * 4
        let target = (pixels[start], pixels[start + 1], pixels[start + 2])
        let fill = color.rgb
        let tolerance = 34
        guard colorDistance(target, fill) > tolerance else { return self }

        var queue: [(Int, Int)] = [(x, y)]
        var cursor = 0
        var visited = Set<Int>()
        while cursor < queue.count {
            let (px, py) = queue[cursor]
            cursor += 1
            guard px >= 0, px < width, py >= 0, py < height else { continue }
            let index = py * width + px
            guard visited.insert(index).inserted else { continue }

            let offset = index * 4
            let current = (pixels[offset], pixels[offset + 1], pixels[offset + 2])
            guard colorDistance(current, target) <= tolerance else { continue }
            pixels[offset] = fill.0
            pixels[offset + 1] = fill.1
            pixels[offset + 2] = fill.2
            pixels[offset + 3] = 255

            queue.append((px - 1, py))
            queue.append((px + 1, py))
            queue.append((px, py - 1))
            queue.append((px, py + 1))
        }

        guard let outputContext = CGContext(data: &pixels,
                                             width: width,
                                             height: height,
                                             bitsPerComponent: 8,
                                             bytesPerRow: width * 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let output = outputContext.makeImage()
        else { return nil }
        return UIImage(cgImage: output, scale: scale, orientation: imageOrientation)
    }

    private func colorDistance(_ lhs: (UInt8, UInt8, UInt8), _ rhs: (UInt8, UInt8, UInt8)) -> Int {
        abs(Int(lhs.0) - Int(rhs.0)) + abs(Int(lhs.1) - Int(rhs.1)) + abs(Int(lhs.2) - Int(rhs.2))
    }
}

private extension UIColor {
    var rgb: (UInt8, UInt8, UInt8) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255))
        }
        return (0, 0, 0)
    }
}

final class DrawingCanvasView: PKCanvasView {
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundColor = .clear
        isOpaque = false
        contentInset = .zero
        contentOffset = .zero
        minimumZoomScale = 1
        maximumZoomScale = 1
        zoomScale = 1
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
    }
}

struct PencilCanvas: UIViewRepresentable {
    @Binding var canvas: DrawingCanvasView
    var tool: PKTool

    func makeUIView(context: Context) -> DrawingCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = tool
        return canvas
    }

    func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        uiView.tool = tool
    }
}
