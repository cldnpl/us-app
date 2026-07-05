import Foundation

/// A coarse menstrual-cycle phase. Kept intentionally simple — it's what drives
/// the copy shown to each partner, and the only thing ever shared off-device.
/// Raw values are the wire format (must match the backend's validCyclePhases).
enum CyclePhase: String, Codable, CaseIterable {
    case menstrual, follicular, ovulation, luteal, pms

    /// Shown to the person whose cycle it is.
    var title: String {
        switch self {
        case .menstrual:  return "Period"
        case .follicular: return "Follicular phase"
        case .ovulation:  return "Ovulation"
        case .luteal:     return "Luteal phase"
        case .pms:        return "PMS window"
        }
    }

    /// A plain-language description for the detail screen.
    var detail: String {
        switch self {
        case .menstrual:  return "Your period. Rest and be kind to yourself."
        case .follicular: return "Rising energy as your body prepares to ovulate."
        case .ovulation:  return "Your fertile window — ovulation is around now."
        case .luteal:     return "The wind-down after ovulation, before your next period."
        case .pms:        return "The days before your period — mood and energy may dip."
        }
    }

    /// A gentle heads-up shown to the *partner* (never clinical, never symptoms).
    var partnerHint: String {
        switch self {
        case .menstrual:  return "She may want comfort and rest 💛"
        case .follicular: return "Energy's on the rise ✨"
        case .ovulation:  return "Peak energy — and the fertile window 🌸"
        case .luteal:     return "Winding down — a little extra care goes far 💛"
        case .pms:        return "Be extra patient and sweet these days 💛"
        }
    }

    /// Concrete, kind things a partner (who doesn't have a cycle himself) can do
    /// this phase to help her feel good. Shown as a checklist in "his" view.
    var partnerTips: [String] {
        switch self {
        case .menstrual:
            return ["Bring her favorite snacks or a warm drink",
                    "Offer a heating pad and let her rest",
                    "Quietly take chores off her plate",
                    "Be patient — low energy and cramps are normal"]
        case .follicular:
            return ["Her energy's rising — suggest something active or social",
                    "Great week for a date or trying something new together",
                    "Match her upbeat, motivated mood"]
        case .ovulation:
            return ["She may feel confident and social — plan a fun night out",
                    "Extra affection and compliments land really well now",
                    "If you're trying for a baby, this is the fertile window"]
        case .luteal:
            return ["Energy starts dipping — keep plans cozy and low-key",
                    "Handle dinner or cook her something she loves",
                    "Give extra reassurance and cuddles",
                    "Don't take small mood shifts personally"]
        case .pms:
            return ["Be extra patient, gentle, and reassuring",
                    "Bring chocolate or her go-to comfort food",
                    "Listen more, fix less",
                    "Take care of chores without being asked"]
        }
    }

    var symbol: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation:  return "sparkles"
        case .luteal:     return "moon.fill"
        case .pms:        return "cloud.fill"
        }
    }
}

/// Everything the app derives locally about the current cycle.
struct CycleInsights: Equatable {
    let phase: CyclePhase
    let cycleDay: Int
    let cycleLength: Int
    let daysUntilNextPeriod: Int
    let predictedNextPeriod: Date
    let currentCycleStart: Date
    /// True when we had too little history and fell back to a 28-day estimate.
    let isEstimated: Bool
}

/// Pure, testable cycle math. Takes the period-start dates read from Apple Health
/// and derives the current day, phase, and next-period prediction. Everything is
/// an estimate — the UI says so — never a medical claim.
enum CycleEngine {
    static let defaultCycleLength = 28
    static let periodLength = 5

    static func insights(fromPeriodStarts starts: [Date],
                         today: Date = Date(),
                         calendar: Calendar = .current) -> CycleInsights? {
        let days = Array(Set(starts.map { calendar.startOfDay(for: $0) })).sorted()
        guard let last = days.last else { return nil }
        let today0 = calendar.startOfDay(for: today)

        let cycleLength = averageCycleLength(days, calendar: calendar)

        // Most recent cycle start on/before today. Roll forward from the last
        // logged start so a few weeks of not logging still lands on the right day.
        let gap = calendar.dateComponents([.day], from: last, to: today0).day ?? 0
        let cyclesElapsed = gap > 0 ? gap / cycleLength : 0
        let currentStart = calendar.date(byAdding: .day, value: cyclesElapsed * cycleLength, to: last) ?? last

        let cycleDay = max(1, (calendar.dateComponents([.day], from: currentStart, to: today0).day ?? 0) + 1)
        let predictedNext = calendar.date(byAdding: .day, value: cycleLength, to: currentStart) ?? today0
        let daysUntil = max(0, calendar.dateComponents([.day], from: today0, to: predictedNext).day ?? 0)

        return CycleInsights(
            phase: phase(cycleDay: cycleDay, cycleLength: cycleLength, daysUntilNext: daysUntil),
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            daysUntilNextPeriod: daysUntil,
            predictedNextPeriod: predictedNext,
            currentCycleStart: currentStart,
            isEstimated: days.count < 2)
    }

    /// Mean gap of the last few cycles, clamped to a sane 21–35 days.
    static func averageCycleLength(_ starts: [Date], calendar: Calendar) -> Int {
        guard starts.count >= 2 else { return defaultCycleLength }
        var gaps: [Int] = []
        for i in 1..<starts.count {
            if let g = calendar.dateComponents([.day], from: starts[i - 1], to: starts[i]).day,
               (15...60).contains(g) {
                gaps.append(g)
            }
        }
        guard !gaps.isEmpty else { return defaultCycleLength }
        let recent = gaps.suffix(6)
        let avg = Int((Double(recent.reduce(0, +)) / Double(recent.count)).rounded())
        return min(35, max(21, avg))
    }

    static func phase(cycleDay: Int, cycleLength: Int, daysUntilNext: Int) -> CyclePhase {
        if cycleDay <= periodLength { return .menstrual }
        if daysUntilNext <= 3 { return .pms }
        let ovulationDay = max(periodLength + 2, cycleLength - 14)
        if abs(cycleDay - ovulationDay) <= 1 { return .ovulation }
        return cycleDay < ovulationDay ? .follicular : .luteal
    }
}
