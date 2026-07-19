import SwiftUI
import UIKit

// MARK: - Entry

struct SnapHuntView: View {
    @EnvironmentObject var session: Session
    @State private var round: SnapRound?
    @State private var picked: UIImage?
    @State private var showPicker = false
    @State private var submitting = false
    @State private var errorMessage: String?

    private var partnerName: String { session.partner?.displayName ?? "your partner" }
    private var accent: Color { QuizPalette.accent("green") }

    var body: some View {
        ZStack {
            Theme.softBackground.ignoresSafeArea()
            if let round {
                if round.mySubmitted {
                    revealScreen(round)
                } else {
                    huntScreen(round)
                }
            } else if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Snap Hunt")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(isPresented: $showPicker) {
            CameraPicker { image in picked = image }
                .ignoresSafeArea()
        }
    }

    // MARK: hunt

    @ViewBuilder
    private func huntScreen(_ round: SnapRound) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("FIND").font(.caption2.bold()).tracking(2).foregroundStyle(accent)
                    Text("“\(round.clue)”")
                        .font(.title.bold()).multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                    Text(round.partnerSubmitted
                         ? "\(partnerName) already found theirs — quick!"
                         : "Race around the house and snap your cleverest find.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let picked {
                    Image(uiImage: picked)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(spacing: 10) {
                        Button { Task { await submit(picked) } } label: {
                            if submitting { ProgressView() }
                            else { Label("Use this photo", systemImage: "checkmark").font(.subheadline.bold()) }
                        }
                        .buttonStyle(PillButtonStyle(color: accent))
                        .frame(maxWidth: .infinity)
                        .disabled(submitting)

                        Button { showPicker = true } label: {
                            Label("Retake", systemImage: "camera.rotate").font(.footnote.bold())
                        }
                        .foregroundStyle(accent)
                    }
                } else {
                    Button { showPicker = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.viewfinder").font(.system(size: 44))
                            Text("Snap a photo").font(.headline)
                        }
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity).padding(.vertical, 36)
                        .background(QuizPalette.gradient("green").opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
    }

    // MARK: reveal / waiting

    @ViewBuilder
    private func revealScreen(_ round: SnapRound) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("“\(round.clue)”")
                    .font(.title3.bold()).multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink).padding(.top, 8)

                if round.revealed {
                    VStack(spacing: 6) {
                        Image(systemName: crownIcon(round.outcome)).font(.system(size: 48)).foregroundStyle(accent)
                        Text(crownTitle(round.outcome)).font(.title3.bold()).foregroundStyle(Theme.ink)
                        if let reason = round.reason {
                            Text(reason).font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 20)
                        }
                    }
                    photoCard(title: "You", path: round.myImagePath, winner: round.outcome == "me")
                    photoCard(title: partnerName, path: round.partnerImagePath, winner: round.outcome == "partner")
                } else {
                    VStack(spacing: 12) {
                        QuizIconTile(systemName: "hourglass", colorKey: "green", size: 64).padding(.top, 8)
                        Text("Got it! 📸").font(.title3.bold()).foregroundStyle(Theme.ink)
                        Text("Your find is locked in. The judge crowns a winner once \(partnerName) snaps theirs too.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    photoCard(title: "Your find", path: round.myImagePath, winner: false)
                }

                VStack(spacing: 10) {
                    Button { Task { await newRound() } } label: {
                        Label("New hunt", systemImage: "arrow.clockwise").font(.subheadline.bold())
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

    private func photoCard(title: String, path: String?, winner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                if winner {
                    Spacer()
                    Label("Cleverest", systemImage: "crown.fill").font(.caption2.bold()).foregroundStyle(accent)
                }
            }
            Group {
                if let path {
                    RemoteImage(path: path, contentMode: .fit)
                } else {
                    Rectangle().fill(.quaternary).overlay(ProgressView())
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(QuizPalette.gradient("green").opacity(winner ? 0.6 : 0.35),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func crownIcon(_ outcome: String?) -> String {
        switch outcome {
        case "me": return "crown.fill"
        case "partner": return "flag.checkered"
        default: return "equal.circle.fill"
        }
    }

    private func crownTitle(_ outcome: String?) -> String {
        switch outcome {
        case "me": return "You found the cleverest! 🏆"
        case "partner": return "\(partnerName) wins this hunt 😄"
        default: return "It's a tie — both brilliant! 🤝"
        }
    }

    // MARK: actions

    private func load() async {
        do { round = try await APIClient.shared.getSnap() }
        catch { errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription }
    }

    private func reload() async { round = try? await APIClient.shared.getSnap() }

    private func submit(_ image: UIImage) async {
        guard !submitting, let data = image.jpegData(compressionQuality: 0.85) else { return }
        submitting = true; errorMessage = nil
        defer { submitting = false }
        do {
            round = try await APIClient.shared.submitSnap(data)
            picked = nil
            Haptics.success()
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }

    private func newRound() async {
        do {
            round = try await APIClient.shared.newSnap()
            picked = nil
            Haptics.tap(.light)
        } catch {
            errorMessage = (error as? APIErrorResponse)?.error ?? error.localizedDescription
        }
    }
}

// MARK: - Camera / photo picker

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
