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

private let widgetRose = Color(red: 0.76, green: 0.31, blue: 0.47)
private let roseGradient = LinearGradient(
    colors: [widgetRose, widgetRose.opacity(0.82)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

struct UsWidgetEntryView: View {
    var entry: UsEntry

    var body: some View {
        Group {
            if #available(iOS 17.0, *) {
                // Interactive: tapping runs the intent in the background and
                // sends "I miss you" WITHOUT opening the app.
                Button(intent: MissYouIntent()) { info }
                    .buttonStyle(.plain)
            } else {
                // iOS 16 can't run a widget intent, so fall back to a deep link
                // that opens the app, which sends on launch.
                info.widgetURL(SharedConfig.missYouURL)
            }
        }
        .widgetBackground(warmGradient)
    }

    private var info: some View {
        VStack(spacing: 6) {
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
            }
            Label("I miss you", systemImage: "heart.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.22), in: Capsule())
                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .contentShape(Rectangle())
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

struct UsWidget: Widget {
    let kind = "UsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsProvider()) { entry in
            UsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Us.")
        .description("Your days together — tap to send “I miss you”.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Distance widget (Home Screen + Lock Screen)

struct DistanceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct DistanceProvider: TimelineProvider {
    private var sample: WidgetSnapshot {
        WidgetSnapshot(partnerName: "Alex", daysTogether: nil, updatedAt: Date(),
                       myName: "You", distanceKm: 200)
    }
    func placeholder(in context: Context) -> DistanceEntry {
        DistanceEntry(date: Date(), snapshot: sample)
    }
    func getSnapshot(in context: Context, completion: @escaping (DistanceEntry) -> Void) {
        completion(DistanceEntry(date: Date(), snapshot: WidgetStore.load() ?? sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DistanceEntry>) -> Void) {
        let entry = DistanceEntry(date: Date(), snapshot: WidgetStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct DistanceWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DistanceEntry

    private var myName: String { entry.snapshot?.myName ?? "You" }
    private var partnerName: String { entry.snapshot?.partnerName ?? "Partner" }
    private var km: Int? { entry.snapshot?.distanceKm.map { Int($0.rounded()) } }
    private var kmText: String { km.map { "\($0) km" } ?? "— km" }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(kmText) apart", systemImage: "heart.fill")

        case .accessoryCircular:
            accessoryCircular.widgetBackground(Color.clear)

        case .accessoryRectangular:
            accessoryRectangular.widgetBackground(Color.clear)

        default: // systemSmall / systemMedium on the Home Screen
            homeTile.widgetBackground(roseGradient)
        }
    }

    private var accessoryCircular: some View {
        VStack(spacing: 1) {
            Image(systemName: "heart.fill").font(.caption2)
            Text("\(km ?? 0)").font(.system(.headline, design: .rounded).bold())
            Text("km").font(.system(size: 9))
        }
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(kmText) apart").font(.headline)
            HStack(spacing: 4) {
                Text(myName).lineLimit(1)
                Image(systemName: "heart.fill").font(.caption2)
                Text(partnerName).lineLimit(1)
            }
            .font(.caption)
        }
    }

    private var homeTile: some View {
        VStack(spacing: 8) {
            Text(kmText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("apart").font(.caption).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 6) {
                Text(myName).lineLimit(1).minimumScaleFactor(0.6)
                widgetConnector
                Text(partnerName).lineLimit(1).minimumScaleFactor(0.6)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var widgetConnector: some View {
        ZStack {
            Rectangle().fill(.white.opacity(0.7)).frame(width: 34, height: 1.5)
            Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(.white)
        }
    }
}

struct DistanceWidget: Widget {
    let kind = "UsDistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DistanceProvider()) { entry in
            DistanceWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("How far apart you are — on your Home or Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

// MARK: - Bundle

@main
struct UsWidgets: WidgetBundle {
    var body: some Widget {
        UsWidget()
        DistanceWidget()
    }
}
