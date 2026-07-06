import SwiftUI

/// A menstrual-cycle phase. Four phases, each with its own color drawn from the
/// app's warm palette. Raw values are the wire format (kept in sync with the
/// backend's accepted phases).
enum CyclePhase: String, Codable, CaseIterable {
    case menstrual, follicular, ovulation, luteal

    var title: String {
        switch self {
        case .menstrual:  return "Period"
        case .follicular: return "Follicular phase"
        case .ovulation:  return "Ovulation phase"
        case .luteal:     return "Luteal phase"
        }
    }

    /// Distinct per-phase accent color, harmonized with the app's warm palette.
    var color: Color {
        switch self {
        case .menstrual:  return Color(red: 1.00, green: 0.42, blue: 0.42) // coral red
        case .follicular: return Color(red: 0.98, green: 0.68, blue: 0.44) // warm peach
        case .ovulation:  return Color(red: 1.00, green: 0.48, blue: 0.66) // rose pink
        case .luteal:     return Color(red: 0.76, green: 0.55, blue: 0.80) // soft plum
        }
    }

    var symbol: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation:  return "sparkles"
        case .luteal:     return "moon.fill"
        }
    }

    /// Short line shown to the person whose cycle it is.
    var detail: String {
        switch self {
        case .menstrual:  return "Your period. Rest and be kind to yourself."
        case .follicular: return "Rising energy as your body prepares to ovulate."
        case .ovulation:  return "Your fertile window — energy and confidence peak."
        case .luteal:     return "Winding down before your next period."
        }
    }

    /// Gentle one-liner used on the partner's Home card.
    var partnerHint: String {
        switch self {
        case .menstrual:  return "She may want comfort and rest 💛"
        case .follicular: return "Energy's on the rise ✨"
        case .ovulation:  return "Peak energy — and the fertile window 🌸"
        case .luteal:     return "Winding down — a little extra care goes far 💛"
        }
    }

    // MARK: - Supporter explainer (for the partner who doesn't have a cycle)

    /// What the phase is and why it happens.
    var about: String {
        switch self {
        case .menstrual:
            return "The period itself — the uterine lining sheds. Estrogen and progesterone are at their lowest, so energy and mood often dip."
        case .follicular:
            return "After the period, estrogen climbs as the body prepares to release an egg. Energy, mood, and motivation rise through this phase."
        case .ovulation:
            return "Estrogen peaks and an egg is released — the fertile window. Many feel their most confident, social, and energetic."
        case .luteal:
            return "After ovulation, progesterone rises then falls toward the next period. Energy winds down and PMS can appear in the last few days."
        }
    }

    /// Main symptoms and difficulties of the phase.
    var symptoms: String {
        switch self {
        case .menstrual:
            return "Cramps, fatigue, low mood, headaches, and cravings are common. Rest matters most now."
        case .follicular:
            return "Usually the easiest stretch — mostly higher energy. Some notice restlessness or skin changes."
        case .ovulation:
            return "Peak energy and libido; some feel mild cramping or bloating around release."
        case .luteal:
            return "Tiredness, mood swings, irritability, bloating, cravings, and tender breasts — strongest just before the period."
        }
    }

    /// Concrete, kind things a supporting partner can do this phase.
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
            return ["Keep plans cozy and low-key",
                    "Cook or handle dinner",
                    "Give extra reassurance, patience, and cuddles",
                    "Bring her comfort food or chocolate",
                    "Don't take small mood shifts personally"]
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
    let nextPhase: CyclePhase
    let daysToNextPhase: Int
    /// True when we had too little history and fell back to a 28-day estimate.
    let isEstimated: Bool
}

/// Pure, testable cycle math. Takes the period-start dates read from Apple Health
/// and derives the current day, phase, next phase, and next-period prediction.
/// Everything is an estimate — the UI says so — never a medical claim.
enum CycleEngine {
    static let defaultCycleLength = 28
    static let periodLength = 5

    struct Window { let phase: CyclePhase; let start: Int; let end: Int }

    /// The four phase windows (1-based cycle days) for a given cycle length.
    static func windows(cycleLength: Int) -> [Window] {
        let p = periodLength
        let ovulation = max(p + 3, cycleLength - 14) // ~14 days before next period
        return [
            Window(phase: .menstrual,  start: 1,            end: p),
            Window(phase: .follicular, start: p + 1,        end: ovulation - 2),
            Window(phase: .ovulation,  start: ovulation - 1, end: ovulation + 1),
            Window(phase: .luteal,     start: ovulation + 2, end: cycleLength),
        ]
    }

    static func phase(cycleDay: Int, cycleLength: Int) -> CyclePhase {
        let ws = windows(cycleLength: cycleLength)
        return (ws.first { cycleDay >= $0.start && cycleDay <= $0.end } ?? ws[ws.count - 1]).phase
    }

    /// Which phase comes next and how many days until it begins.
    static func phaseProgress(cycleDay: Int, cycleLength: Int) -> (nextPhase: CyclePhase, daysToNextPhase: Int) {
        let ws = windows(cycleLength: cycleLength)
        let current = phase(cycleDay: cycleDay, cycleLength: cycleLength)
        if let idx = ws.firstIndex(where: { $0.phase == current }), idx < ws.count - 1 {
            let next = ws[idx + 1]
            return (next.phase, max(0, next.start - cycleDay))
        }
        // Luteal → next period (a new cycle) at day cycleLength + 1.
        return (.menstrual, max(0, (cycleLength + 1) - cycleDay))
    }

    static func insights(fromPeriodStarts starts: [Date],
                         today: Date = Date(),
                         calendar: Calendar = .current) -> CycleInsights? {
        let days = Array(Set(starts.map { calendar.startOfDay(for: $0) })).sorted()
        guard let last = days.last else { return nil }
        let today0 = calendar.startOfDay(for: today)

        let cycleLength = averageCycleLength(days, calendar: calendar)

        // Most recent cycle start on/before today (roll forward from the last
        // logged start so a few weeks of not logging still lands on the right day).
        let gap = calendar.dateComponents([.day], from: last, to: today0).day ?? 0
        let cyclesElapsed = gap > 0 ? gap / cycleLength : 0
        let currentStart = calendar.date(byAdding: .day, value: cyclesElapsed * cycleLength, to: last) ?? last

        let cycleDay = max(1, min(cycleLength, (calendar.dateComponents([.day], from: currentStart, to: today0).day ?? 0) + 1))
        let predictedNext = calendar.date(byAdding: .day, value: cycleLength, to: currentStart) ?? today0
        let daysUntil = max(0, calendar.dateComponents([.day], from: today0, to: predictedNext).day ?? 0)
        let progress = phaseProgress(cycleDay: cycleDay, cycleLength: cycleLength)

        return CycleInsights(
            phase: phase(cycleDay: cycleDay, cycleLength: cycleLength),
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            daysUntilNextPeriod: daysUntil,
            predictedNextPeriod: predictedNext,
            currentCycleStart: currentStart,
            nextPhase: progress.nextPhase,
            daysToNextPhase: progress.daysToNextPhase,
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
}

// MARK: - Pregnancy

/// Everything derived locally from a due date.
struct PregnancyInsights: Equatable {
    let week: Int          // completed weeks (0…42)
    let daysToDue: Int
    let dueDate: Date
    let trimester: Int     // 1, 2, 3
    let babySize: String
}

/// Pure pregnancy math from a due date (40 weeks / 280 days to term).
enum PregnancyEngine {
    static let termDays = 280

    static func insights(dueDate: Date, today: Date = Date(), calendar: Calendar = .current) -> PregnancyInsights {
        let today0 = calendar.startOfDay(for: today)
        let due0 = calendar.startOfDay(for: dueDate)
        let daysToDue = calendar.dateComponents([.day], from: today0, to: due0).day ?? 0
        let gestationDays = max(0, termDays - daysToDue)
        let week = min(42, gestationDays / 7)
        let trimester = week <= 13 ? 1 : (week <= 27 ? 2 : 3)
        return PregnancyInsights(week: week, daysToDue: daysToDue, dueDate: dueDate,
                                 trimester: trimester, babySize: babySize(week: week))
    }

    /// A friendly size comparison for the given week (nearest defined week).
    static func babySize(week: Int) -> String {
        let sizes: [(Int, String)] = [
            (4, "a poppy seed"), (5, "a sesame seed"), (6, "a lentil"), (7, "a blueberry"),
            (8, "a raspberry"), (9, "a cherry"), (10, "a strawberry"), (11, "a lime"),
            (12, "a plum"), (13, "a peach"), (14, "a lemon"), (15, "an apple"),
            (16, "an avocado"), (17, "a pear"), (18, "a bell pepper"), (19, "a mango"),
            (20, "a banana"), (22, "a papaya"), (24, "an ear of corn"), (26, "a zucchini"),
            (28, "an eggplant"), (30, "a cabbage"), (32, "a squash"), (34, "a cantaloupe"),
            (36, "a honeydew melon"), (38, "a pumpkin"), (40, "a watermelon"),
        ]
        var best = sizes[0].1
        for s in sizes where s.0 <= week { best = s.1 }
        return best
    }

    static func trimesterTitle(_ t: Int) -> String {
        switch t {
        case 1:  return "First trimester"
        case 2:  return "Second trimester"
        default: return "Third trimester"
        }
    }

    /// What's happening this trimester (shown to both).
    static func trimesterAbout(_ t: Int) -> String {
        switch t {
        case 1:
            return "The baby's major organs are forming. She may feel nausea, deep fatigue, and tender breasts — even though there's little to see yet."
        case 2:
            return "Often the easiest stretch: energy returns and the bump grows. She may feel the baby move for the first time."
        default:
            return "The baby grows fast and settles into position. Sleep gets harder, with possible swelling, backache, and practice contractions."
        }
    }

    /// How the partner can support her this trimester.
    static func trimesterSupport(_ t: Int) -> [String] {
        switch t {
        case 1:
            return ["Be patient with nausea and fatigue",
                    "Handle cooking smells she can't stand",
                    "Let her nap and rest without guilt",
                    "Go with her to the first scans"]
        case 2:
            return ["Plan nice outings while she has energy",
                    "Start prepping the nursery together",
                    "Talk and sing to the bump",
                    "Help with back or hip aches"]
        default:
            return ["Get her comfortable — pillows, foot rubs",
                    "Take over the heavy lifting and chores",
                    "Pack the hospital bag together",
                    "Know the plan for the big day"]
        }
    }
}
