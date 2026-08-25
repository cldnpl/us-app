import WidgetKit
import SwiftUI
import CoreLocation

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
        // Tapping the widget simply opens the app (no action, no send).
        // "I miss you" is sent only from the button on the Home screen.
        info.widgetBackground(warmGradient)
    }

    private var info: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.fill").font(.title3).foregroundStyle(.white)
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
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        .description("Your days together — tap to open the app.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Distance widget (Home Screen + Lock Screen)

struct DistanceEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct DistanceProvider: TimelineProvider {
    /// How often the widget asks the system to reload. WidgetKit budgets the
    /// actual cadence, but asking every 15 minutes keeps the distance moving on
    /// its own — nobody has to tap the widget or open the app.
    private static let refreshMinutes = 15

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
        Task {
            // Recompute from live data: our own position (from the widget when
            // it is allowed to have one, otherwise the app's last fix) and the
            // partner's current position fetched straight from the backend.
            //
            // Under a deadline, because none of it is allowed to cost us the
            // widget: a silent location request or an unreachable backend used
            // to leave this provider hanging, `completion` was never called,
            // and WidgetKit had nothing to draw but its grey placeholder —
            // which then took the days-together widget down with it, both
            // living in the same throttled extension. A stale distance is a far
            // better outcome than a blank widget.
            await withDeadline(seconds: 8) {
                let mine = await WidgetLocation.current() ?? MyLocationStore.coordinate
                await DistanceSync.refresh(myCoordinate: mine)
            }

            let entry = DistanceEntry(date: Date(), snapshot: WidgetStore.load())
            let next = Calendar.current.date(byAdding: .minute, value: Self.refreshMinutes, to: Date())
                ?? Date().addingTimeInterval(TimeInterval(Self.refreshMinutes * 60))
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

/// Runs `work`, giving up after `seconds`. Never fails — the caller carries on
/// with whatever data it already has, which for a timeline provider is the
/// difference between a slightly stale widget and no widget at all.
private func withDeadline(seconds: Double, _ work: @escaping @Sendable () async -> Void) async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await work() }
        group.addTask { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
        _ = await group.next()   // whichever finishes first
        group.cancelAll()
    }
}

/// Lets the widget read the device's own location while it refreshes.
///
/// Only works when the user granted "Always" access (the widget declares
/// `NSWidgetWantsLocation`); otherwise `isAuthorizedForWidgetUpdates` is false
/// and we fall back to the last fix the app stored in the App Group.
private final class WidgetLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private static var live: WidgetLocation?

    static func current() async -> CLLocationCoordinate2D? {
        let manager = CLLocationManager()
        guard manager.isAuthorizedForWidgetUpdates else { return nil }
        let requester = WidgetLocation()
        live = requester // keep alive for the duration of the request
        let coordinate = await requester.request()
        live = nil
        return coordinate
    }

    private func request() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
            // CoreLocation can stay silent — neither a fix nor an error. A
            // task group cannot force a checked continuation to finish, so the
            // provider used to remain stuck here and never publish its next
            // timeline. Finish the request ourselves and render the cached
            // distance instead.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.finish(nil)
            }
        }
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        if let coordinate { MyLocationStore.save(coordinate) }
        continuation.resume(returning: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
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

// MARK: - "Been together" widget (Home Screen + Lock Screen)

struct TogetherEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct TogetherProvider: TimelineProvider {
    private var sample: WidgetSnapshot {
        WidgetSnapshot(partnerName: "Alex", daysTogether: 342, updatedAt: Date(), myName: "You", distanceKm: nil)
    }
    func placeholder(in context: Context) -> TogetherEntry { TogetherEntry(date: Date(), snapshot: sample) }
    func getSnapshot(in context: Context, completion: @escaping (TogetherEntry) -> Void) {
        completion(TogetherEntry(date: Date(), snapshot: WidgetStore.load() ?? sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TogetherEntry>) -> Void) {
        let entry = TogetherEntry(date: Date(), snapshot: WidgetStore.load())
        // Refresh just after midnight so the day count ticks over.
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 5),
                                             matchingPolicy: .nextTime) ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TogetherWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TogetherEntry

    private var days: Int { entry.snapshot?.daysTogether ?? 0 }

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(days) days together", systemImage: "heart.fill")
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: "heart.fill").font(.caption2)
                Text("\(days)").font(.system(.title3, design: .rounded).bold())
                Text("days").font(.system(size: 9))
            }
            .widgetBackground(Color.clear)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Been together").font(.caption)
                Text("\(days) days").font(.headline)
            }
            .widgetBackground(Color.clear)
        default:
            homeTile.widgetBackground(roseGradient)
        }
    }

    private var homeTile: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill").font(.title3).foregroundStyle(.white)
            Text("\(days)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("days together").font(.caption).foregroundStyle(.white.opacity(0.9))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct TogetherWidget: Widget {
    let kind = "UsTogetherWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TogetherProvider()) { entry in
            TogetherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Been together")
        .description("How long you've been together.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

@main
struct UsWidgets: WidgetBundle {
    var body: some Widget {
        UsWidget()
        DistanceWidget()
        TogetherWidget()
    }
}
