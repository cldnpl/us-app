import WidgetKit
import SwiftUI

struct UsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct UsProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsEntry {
        UsEntry(date: Date(), snapshot: WidgetSnapshot(partnerName: "Alex", daysTogether: 342, updatedAt: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (UsEntry) -> Void) {
        completion(UsEntry(date: Date(), snapshot: WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsEntry>) -> Void) {
        let entry = UsEntry(date: Date(), snapshot: WidgetStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

private let warmGradient = LinearGradient(
    colors: [Color(red: 1, green: 0.71, blue: 0.76),
             Color(red: 1, green: 0.42, blue: 0.42),
             Color(red: 1, green: 0.85, blue: 0.73)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

struct UsWidgetEntryView: View {
    var entry: UsEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.white)
            if let days = entry.snapshot?.daysTogether {
                Text("\(days)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("days together")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(entry.snapshot?.partnerName ?? "Us.")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Tap to say hi 💜")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(warmGradient)
        .widgetURL(URL(string: "usapp://missyou"))
    }
}

/// iOS 17 requires containerBackground; iOS 16 uses a plain background.
private extension View {
    @ViewBuilder
    func widgetBackground(_ background: some View) -> some View {
        if #available(iOS 17.0, *) {
            containerBackground(for: .widget) { background }
        } else {
            self.background(background)
        }
    }
}

@main
struct UsWidget: Widget {
    let kind = "UsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsProvider()) { entry in
            UsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Us.")
        .description("Your days together — tap to open.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
