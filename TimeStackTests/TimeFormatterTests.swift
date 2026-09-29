import Foundation
import Testing

/// The overlay's digits are the whole product, so the formatter is pinned
/// case by case.
struct TimeFormatterTests {

    @Test("Whole seconds: MM:SS under an hour, H:MM:SS from an hour")
    func wholeSeconds() {
        #expect(TimeFormatter.format(0, precision: 0) == "00:00")
        #expect(TimeFormatter.format(59, precision: 0) == "00:59")
        #expect(TimeFormatter.format(20 * 60, precision: 0) == "20:00")
        #expect(TimeFormatter.format(3599, precision: 0) == "59:59")
        #expect(TimeFormatter.format(3600, precision: 0) == "1:00:00")
        #expect(TimeFormatter.format(36_000 + 61, precision: 0) == "10:01:01")
    }

    @Test("Negative intervals clamp to zero")
    func negative() {
        #expect(TimeFormatter.format(-5, precision: 0) == "00:00")
        #expect(TimeFormatter.format(-0.01, precision: 2) == "00:00.00")
    }

    @Test("Tenths and hundredths truncate rather than round up")
    func truncation() {
        #expect(TimeFormatter.format(0.99, precision: 1) == "00:00.9")
        #expect(TimeFormatter.format(59.999, precision: 2) == "00:59.99")
        #expect(TimeFormatter.format(1.05, precision: 1) == "00:01.0")
    }

    /// Regression: values like 12.34 are stored as 12.3399999… in binary
    /// floating point, and the pre-2026-09-28 formatter displayed "12.33".
    @Test("Decimal values display their own digits", arguments: [
        (0.29, "00:00.29"), (0.57, "00:00.57"), (1.15, "00:01.15"),
        (12.34, "00:12.34"), (0.3, "00:00.30"), (3599.99, "59:59.99"),
    ])
    func floatingPointRepresentation(value: Double, expected: String) {
        #expect(TimeFormatter.format(value, precision: 2) == expected)
    }

    @Test("Precision 1 is the default")
    func defaultPrecision() {
        #expect(TimeFormatter.format(83.46) == "01:23.4")
    }
}
