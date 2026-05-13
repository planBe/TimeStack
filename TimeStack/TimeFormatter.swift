import Foundation

enum TimeFormatter {

    /// Formats a TimeInterval as "MM:SS" (or "H:MM:SS" if hours > 0), optionally with
    /// a tenths-of-a-second suffix.
    static func format(_ interval: TimeInterval, showsTenths: Bool = false) -> String {
        let total = max(0, interval)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60
        let tenths = Int((total.truncatingRemainder(dividingBy: 1)) * 10)

        if hours > 0 {
            return showsTenths
                ? String(format: "%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
                : String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return showsTenths
            ? String(format: "%02d:%02d.%d", minutes, seconds, tenths)
            : String(format: "%02d:%02d", minutes, seconds)
    }
}
