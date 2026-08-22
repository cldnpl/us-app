import SwiftUI
import AVKit

/// Guides the user through adding the Us. widget to their Home Screen.
///
/// iOS doesn't let an app place its own widget — only the person can, from the
/// system widget gallery — so the only thing we can do is show them how. A
/// screen recording of the real thing does that far better than a numbered
/// list: the widget gallery looks nothing like our UI, and "touch and hold an
/// empty area" is a lot easier to recognise than to read.
///
/// The written steps stay underneath: the video is silent and carries no text,
/// so it's useless to VoiceOver, and a person who prefers reading shouldn't
/// have to watch 13 seconds to find out where the ＋ is.
struct AddWidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = LoopingPlayer(resource: "add-widget", extension: "mp4")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    video
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 18) {
                        step(1, "Touch and hold an empty area of your Home Screen until the apps jiggle.")
                        step(2, "Tap the **＋** button in the top-left corner.")
                        step(3, "Search for **Us.** and pick a widget size.")
                        step(4, "Tap **Add Widget**, then **Done**.")
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Label {
                        Text("Tapping the widget sends **“I miss you”** to \(PartnerPrefs.partnerName ?? "your partner") — without opening the app.")
                    } icon: {
                        Image(systemName: "heart.fill").foregroundStyle(Theme.rose)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .background(Theme.softBackground.ignoresSafeArea())
            .navigationTitle("Add widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { player.play() }
            .onDisappear { player.pause() }
        }
    }

    /// The recording, in a phone-shaped frame so it reads as "this is your Home
    /// Screen" rather than as a video embedded in the page. Falls back to the
    /// old widget mock-up if the file is ever missing from the bundle.
    @ViewBuilder
    private var video: some View {
        if let queue = player.queue {
            VideoPlayer(player: queue)
                .aspectRatio(540.0 / 1170.0, contentMode: .fit)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
                .accessibilityLabel("A recording showing how to add the Us. widget to the Home Screen. The written steps are below.")
        } else {
            widgetPreview
        }
    }

    /// A small on-brand preview mimicking the real widget.
    private var widgetPreview: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill").font(.title3).foregroundStyle(.white)
            Text("342")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("days together").font(.caption).foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 150, height: 150)
        .background(Theme.roseGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Theme.rose.opacity(0.35), radius: 16, y: 8)
        .overlay(alignment: .bottom) {
            Text("Us.")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .offset(y: 22)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.rose, in: Circle())
            Text(.init(text))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Plays a bundled clip on a loop, muted.
///
/// `AVPlayerLooper` needs its queue player and its template item to stay alive
/// for the whole time — held by a plain `@State` they get released mid-playback
/// and the video freezes on its first frame, so they live here instead.
@MainActor
final class LoopingPlayer: ObservableObject {
    let queue: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(resource: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            queue = nil
            return
        }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        looper = AVPlayerLooper(player: player, templateItem: item)
        queue = player
    }

    func play() { queue?.play() }
    func pause() { queue?.pause() }
}
