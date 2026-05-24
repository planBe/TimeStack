import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - User-configurable state (v0.1)

    @Published var countdownTarget: TimeInterval {
        didSet { saveSettings() }
    }
    @Published var countdownVisible: Bool {
        didSet { saveSettings() }
    }
    @Published var stopwatchVisible: Bool {
        didSet { saveSettings() }
    }

    // MARK: - User-configurable state (v0.2)

    /// 0 = whole seconds (MM:SS), 1 = tenths (MM:SS.X), 2 = hundredths (MM:SS.XX).
    @Published var precision: Int {
        didSet { saveSettings() }
    }
    @Published var countdownColor: Color {
        didSet { saveSettings() }
    }
    @Published var stopwatchColor: Color {
        didSet { saveSettings() }
    }
    @Published var soundEnabled: Bool {
        didSet { saveSettings() }
    }
    /// macOS system sound name (e.g. "Glass", "Funk", "Ping") or "None" to disable.
    @Published var countdownEndSound: String {
        didSet { saveSettings() }
    }

    // MARK: - User-configurable state (v0.3)

    /// Seconds of "get ready" countdown before any Start action actually starts the timers.
    /// 0 = disabled (immediate start, v0.2 behavior). Range 0–10, default 3.
    @Published var delaySeconds: Int {
        didSet {
            delaySeconds = max(0, min(10, delaySeconds))
            saveSettings()
        }
    }

    // MARK: - Transient delay-start state (not persisted)

    enum PendingStartAction { case countdown, stopwatch, both }

    /// Non-nil during the delay-before-start phase. Counts down 3 → 2 → 1, then fires `pendingAction`.
    @Published private(set) var delayRemaining: Int?
    @Published private(set) var pendingAction: PendingStartAction?

    private var delayTickTimer: Timer?

    // MARK: - Derived display state (read-only externally)

    @Published private(set) var countdownRemaining: TimeInterval
    @Published private(set) var countdownRunning: Bool = false
    @Published private(set) var stopwatchElapsed: TimeInterval = 0
    @Published private(set) var stopwatchRunning: Bool = false

    // MARK: - Internal tracking

    private var countdownStartedAt: Date?
    private var countdownPausedRemaining: TimeInterval

    private var stopwatchStartedAt: Date?
    private var stopwatchPausedElapsed: TimeInterval = 0

    private var displayTimer: Timer?
    /// 50ms tick — fast enough for smooth hundredths display.
    private let displayInterval: TimeInterval = 0.05

    private let settingsKey = "TimeStack.settings.v2"
    private let legacyKeyV1 = "TimeStack.settings.v1"

    // MARK: - Defaults

    static let defaultCountdownColor = Color(red: 0.20, green: 0.47, blue: 0.96)  // #3478F6
    static let defaultStopwatchColor = Color(red: 0.19, green: 0.82, blue: 0.35)  // #30D158
    static let defaultCountdownEndSound = "Glass"
    /// macOS-bundled NSSound names that are present on every install since 10.6.
    static let availableSystemSounds: [String] = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    // MARK: - Init

    init() {
        let dict = TimerEngine.loadSettingsDict(
            v2Key: "TimeStack.settings.v2",
            v1Key: "TimeStack.settings.v1"
        )

        let target = (dict["countdownTarget"] as? TimeInterval) ?? 1200
        self.countdownTarget = target
        self.countdownRemaining = target
        self.countdownPausedRemaining = target
        self.countdownVisible = (dict["countdownVisible"] as? Bool) ?? true
        self.stopwatchVisible = (dict["stopwatchVisible"] as? Bool) ?? true

        self.precision = (dict["precision"] as? Int) ?? 1
        if let hex = dict["countdownColorHex"] as? String, let color = Color(hex: hex) {
            self.countdownColor = color
        } else {
            self.countdownColor = TimerEngine.defaultCountdownColor
        }
        if let hex = dict["stopwatchColorHex"] as? String, let color = Color(hex: hex) {
            self.stopwatchColor = color
        } else {
            self.stopwatchColor = TimerEngine.defaultStopwatchColor
        }
        self.soundEnabled = (dict["soundEnabled"] as? Bool) ?? false
        self.countdownEndSound = (dict["countdownEndSound"] as? String) ?? TimerEngine.defaultCountdownEndSound
        self.delaySeconds = max(0, min(10, (dict["delaySeconds"] as? Int) ?? 3))

        startDisplayLoop()
    }

    deinit {
        displayTimer?.invalidate()
        delayTickTimer?.invalidate()
    }

    // MARK: - Countdown control

    func startCountdown() {
        if delayRemaining != nil { cancelDelay(); return }
        if delaySeconds > 0 {
            beginDelay(for: .countdown)
        } else {
            startCountdownNow()
        }
    }

    private func startCountdownNow() {
        guard !countdownRunning else { return }
        if countdownPausedRemaining <= 0 {
            countdownPausedRemaining = countdownTarget
            countdownRemaining = countdownTarget
        }
        countdownStartedAt = Date()
        countdownRunning = true
    }

    func stopCountdown() {
        guard countdownRunning else { return }
        countdownPausedRemaining = countdownRemaining
        countdownStartedAt = nil
        countdownRunning = false
    }

    func resetCountdown() {
        countdownStartedAt = nil
        countdownRunning = false
        countdownPausedRemaining = countdownTarget
        countdownRemaining = countdownTarget
    }

    // MARK: - Stopwatch control

    func startStopwatch() {
        if delayRemaining != nil { cancelDelay(); return }
        if delaySeconds > 0 {
            beginDelay(for: .stopwatch)
        } else {
            startStopwatchNow()
        }
    }

    private func startStopwatchNow() {
        guard !stopwatchRunning else { return }
        stopwatchStartedAt = Date()
        stopwatchRunning = true
    }

    func stopStopwatch() {
        guard stopwatchRunning else { return }
        stopwatchPausedElapsed = stopwatchElapsed
        stopwatchStartedAt = nil
        stopwatchRunning = false
    }

    func resetStopwatch() {
        stopwatchStartedAt = nil
        stopwatchRunning = false
        stopwatchPausedElapsed = 0
        stopwatchElapsed = 0
    }

    // MARK: - Both-at-once convenience

    func startBoth() {
        if delayRemaining != nil { cancelDelay(); return }
        if delaySeconds > 0 {
            beginDelay(for: .both)
        } else {
            startCountdownNow()
            startStopwatchNow()
        }
    }

    func stopBoth() {
        stopCountdown()
        stopStopwatch()
    }

    func resetBoth() {
        resetCountdown()
        resetStopwatch()
    }

    // MARK: - Sound preview (for the menu's test button)

    func previewCurrentSound() {
        playEndSound()
    }

    private func playEndSound() {
        guard soundEnabled, countdownEndSound != "None" else { return }
        NSSound(named: countdownEndSound)?.play()
    }

    // MARK: - Delay-start state machine (v0.3)

    private func beginDelay(for action: PendingStartAction) {
        cancelDelay()
        pendingAction = action
        delayRemaining = delaySeconds
        delayTickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.delayTick()
            }
        }
    }

    private func delayTick() {
        guard let current = delayRemaining else { return }
        if current <= 1 {
            let action = pendingAction
            delayRemaining = nil
            pendingAction = nil
            delayTickTimer?.invalidate()
            delayTickTimer = nil
            switch action {
            case .countdown: startCountdownNow()
            case .stopwatch: startStopwatchNow()
            case .both:
                startCountdownNow()
                startStopwatchNow()
            case .none: break
            }
        } else {
            delayRemaining = current - 1
        }
    }

    private func cancelDelay() {
        delayRemaining = nil
        pendingAction = nil
        delayTickTimer?.invalidate()
        delayTickTimer = nil
    }

    // MARK: - Display loop

    private func startDisplayLoop() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        if countdownRunning, let startedAt = countdownStartedAt {
            let elapsedSinceStart = Date().timeIntervalSince(startedAt)
            let remaining = countdownPausedRemaining - elapsedSinceStart
            countdownRemaining = max(0, remaining)
            if remaining <= 0 {
                countdownPausedRemaining = 0
                countdownStartedAt = nil
                countdownRunning = false
                playEndSound()
            }
        }

        if stopwatchRunning, let startedAt = stopwatchStartedAt {
            let elapsedSinceStart = Date().timeIntervalSince(startedAt)
            stopwatchElapsed = stopwatchPausedElapsed + elapsedSinceStart
        }
    }

    // MARK: - Persistence

    private func saveSettings() {
        let dict: [String: Any] = [
            "countdownTarget": countdownTarget,
            "countdownVisible": countdownVisible,
            "stopwatchVisible": stopwatchVisible,
            "precision": precision,
            "countdownColorHex": countdownColor.hexString ?? "",
            "stopwatchColorHex": stopwatchColor.hexString ?? "",
            "soundEnabled": soundEnabled,
            "countdownEndSound": countdownEndSound,
            "delaySeconds": delaySeconds,
        ]
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }

    private static func loadSettingsDict(v2Key: String, v1Key: String) -> [String: Any] {
        if let v2 = UserDefaults.standard.dictionary(forKey: v2Key) {
            return v2
        }
        // Backward-compat: read v1 (v0.1's storage) and migrate forward at first save.
        return UserDefaults.standard.dictionary(forKey: v1Key) ?? [:]
    }
}

// MARK: - Color ↔ hex persistence helpers

extension Color {
    init?(hex: String) {
        let stripped = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard stripped.count == 6, let value = UInt32(stripped, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String? {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
