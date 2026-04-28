import Foundation

enum Formatters {
    private static let resetFmt: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.day, .hour, .minute]
        f.maximumUnitCount = 2
        return f
    }()

    private static let updatedFmt: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.day, .hour, .minute, .second]
        f.maximumUnitCount = 1
        return f
    }()

    static func resetsIn(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "resetting…" }
        if interval < 60 { return "resets in <1m" }
        return "resets in " + (resetFmt.string(from: interval) ?? "?")
    }

    static func updatedAgo(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 1 { return "just now" }
        return (updatedFmt.string(from: interval) ?? "?") + " ago"
    }
}
