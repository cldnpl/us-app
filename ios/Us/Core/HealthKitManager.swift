import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Thin read-only bridge to Apple Health for menstrual-flow data. We never write
/// and never store anything ourselves — the source of truth is whatever app the
/// user logs in (Flo, Clue, or Apple Health itself), synced into HealthKit.
///
/// Note: for privacy, HealthKit never tells us whether the user *granted* read
/// access — only whether the prompt was shown. So "no data" and "denied" look
/// identical, and every caller must treat an empty result as a normal state.
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Presents the Health permission sheet for menstrual-flow read access.
    func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable(),
              let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            throw CycleError.unavailable
        }
        try await store.requestAuthorization(toShare: [], read: [flow])
        #else
        throw CycleError.unavailable
        #endif
    }

    /// Reads menstrual-flow samples from the last `monthsBack` months and returns
    /// the detected period-start dates (oldest first). Empty if none/denied.
    func periodStartDates(monthsBack: Int = 12) async throws -> [Date] {
        #if canImport(HealthKit)
        guard let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else { return [] }
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .month, value: -monthsBack, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(sampleType: flow, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, result, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: (result as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        return Self.periodStarts(from: samples, calendar: calendar)
        #else
        return []
        #endif
    }

    #if canImport(HealthKit)
    /// Reduces raw flow samples to period-start days: any sample explicitly
    /// flagged as a cycle start, plus the first flow day after a ≥2-day gap.
    ///
    /// We treat every menstrual-flow sample as a bleeding day rather than reading
    /// the flow level — tracking apps only write these on actual period days, and
    /// it keeps us off the deprecated `HKCategoryValueMenstrualFlow` enum. The
    /// ≥2-day-gap clustering below tolerates the odd stray sample.
    static func periodStarts(from samples: [HKCategorySample], calendar: Calendar) -> [Date] {
        let flowDays = Set(samples.map { calendar.startOfDay(for: $0.startDate) })

        var starts = Set(samples
            .filter { ($0.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool) == true }
            .map { calendar.startOfDay(for: $0.startDate) })

        var previous: Date?
        for day in flowDays.sorted() {
            if let previous,
               let gap = calendar.dateComponents([.day], from: previous, to: day).day,
               gap <= 2 {
                // Same period run — keep going.
            } else {
                starts.insert(day) // first ever, or first day after a break
            }
            previous = day
        }
        return starts.sorted()
    }
    #endif

    enum CycleError: LocalizedError {
        case unavailable
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Health data isn't available on this device."
            }
        }
    }
}
