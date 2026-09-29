import Foundation

enum TimeFormatter {

    /// Formats a TimeInterval as MM:SS (or H:MM:SS if hours > 0), with optional fractional digits.
    /// - Parameter precision: 0 = whole seconds, 1 = tenths (.X), 2 = hundredths (.XX).
    static func format(_ interval: TimeInterval, precision: Int = 1) -> String {
        // Every displayed digit truncates (a running timer shouldn't show a
        // digit before it's reached), but binary floating point stores e.g.
        // 12.34 as 12.3399999… and a computed 13.0 as 12.9999999…, which plain
        // truncation displayed as "12.33" and "12.99". Nudging the whole value
        // by 0.1 µs (far below any displayed digit) before splitting it into
        // fields absorbs that representation error without rounding up real
        // values, and keeps the seconds digit consistent with the fraction.
        let total = max(0, interval) + 1e-7
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60

        let base = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)

        let fraction = total.truncatingRemainder(dividingBy: 1)

        switch precision {
        case 1:
            let tenths = Int(fraction * 10)
            return "\(base).\(min(9, max(0, tenths)))"
        case 2:
            let hundredths = Int(fraction * 100)
            return String(format: "%@.%02d", base, min(99, max(0, hundredths)))
        default:
            return base
        }
    }
}
