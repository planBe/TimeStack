import Foundation

enum TimeFormatter {

    /// Formats a TimeInterval as MM:SS (or H:MM:SS if hours > 0), with optional fractional digits.
    /// - Parameter precision: 0 = whole seconds, 1 = tenths (.X), 2 = hundredths (.XX).
    static func format(_ interval: TimeInterval, precision: Int = 1) -> String {
        let total = max(0, interval)
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = Int(total) % 60

        let base = hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)

        // Fractional digits truncate (a running timer shouldn't show a digit
        // before it's reached), but binary floating point stores e.g. 12.34 as
        // 12.3399999…, which plain truncation displayed as "12.33". The tiny
        // epsilon (0.1 µs, far below any displayed digit) absorbs that
        // representation error without rounding up real values.
        let fraction = total.truncatingRemainder(dividingBy: 1) + 1e-7

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
