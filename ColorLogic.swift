import SwiftUI

struct DueColorScheme {
    // Days thresholds are *minimum days remaining* to fall into that color.
    // Blue = no due date or >= blueMinDays
    // Yellow >= yellowMinDays and < blueMinDays
    // Orange >= orangeMinDays and < yellowMinDays
    // Red >= redMinDays and < orangeMinDays
    // Crimson < redMinDays (overdue also maps to crimson)
    var blueMinDays: Int
    var yellowMinDays: Int
    var orangeMinDays: Int
    var redMinDays: Int

    static func load() -> DueColorScheme {
        let d = UserDefaults.standard
        return .init(
            blueMinDays:   max(0, d.integer(forKey: "blueMinDays")   == 0 ? 30 : d.integer(forKey: "blueMinDays")),
            yellowMinDays: max(0, d.integer(forKey: "yellowMinDays") == 0 ? 15 : d.integer(forKey: "yellowMinDays")),
            orangeMinDays: max(0, d.integer(forKey: "orangeMinDays") == 0 ? 8  : d.integer(forKey: "orangeMinDays")),
            redMinDays:    max(0, d.integer(forKey: "redMinDays")    == 0 ? 0  : d.integer(forKey: "redMinDays"))
        )
    }

    static func save(_ s: DueColorScheme) {
        let d = UserDefaults.standard
        d.set(s.blueMinDays,   forKey: "blueMinDays")
        d.set(s.yellowMinDays, forKey: "yellowMinDays")
        d.set(s.orangeMinDays, forKey: "orangeMinDays")
        d.set(s.redMinDays,    forKey: "redMinDays")
    }
}

func daysUntil(_ date: Date) -> Int {
    let start = Calendar.current.startOfDay(for: Date())
    let end = Calendar.current.startOfDay(for: date)
    let comps = Calendar.current.dateComponents([.day], from: start, to: end)
    return comps.day ?? 0
}

func colorForTask(_ task: Task, scheme: DueColorScheme = .load()) -> Color {
    guard task.status == .pending else { return .secondary }
    guard let due = task.dueDate else { return Color.blue } // No due date → Blue

    let d = daysUntil(due)

    if d >= scheme.blueMinDays { return .blue }
    if d >= scheme.yellowMinDays { return .yellow }
    if d >= scheme.orangeMinDays { return .orange }
    if d >= scheme.redMinDays { return .red }
    return Color(red: 0.6, green: 0.0, blue: 0.0) // Crimson
}