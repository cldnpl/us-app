import SwiftUI

/// Guides the user through adding the Us. widget to their Home Screen.
///
/// iOS doesn't let an app place its own widget (only the user can, from the
/// widget gallery), so we show a clear, on-brand walkthrough with a preview.
/// Once added, tapping the widget sends "I miss you" without opening the app.
struct AddWidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    widgetPreview
                        .padding(.top, 8)

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
