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
    /// When true, plays a soft Tink on each visible digit of the 3-2-1 delay
    /// countdown. Independent from `soundEnabled` (which gates the
    /// countdown-end sound) — a user may want one without the other.
    @Published var delayTickEnabled: Bool {
        didSet { saveSettings() }
    }

    // MARK: - Custom user-picked sound (v1.1)

    /// Display name of the user-picked custom sound file (e.g. "beep.wav").
    /// Nil when no custom sound is set. Published so the menu can show the
    /// filename below the picker when "Custom" is the active selection.
    @Published private(set) var customSoundFileName: String?

    /// Security-Scoped Bookmark blob for the user-picked sound file. Lets
    /// the sandboxed app re-access the file across launches. Private — UI
    /// only needs the filename. Set/cleared via `setCustomSound`/`clearCustomSound`.
    private var customSoundBookmark: Data?

    /// Sentinel tag value for the custom-sound branch in `countdownEndSound`.
    /// Distinct from the system sound names in `availableSystemSounds`.
    static let customSoundTag = "Custom"

    /// Sentinel tag for the bundled "Alarm" sound — a 1s two-tone bee-doo
    /// loop bundled at `Alarm.m4a`. Picked as the new v1.1 default because
    /// macOS system sounds are all sub-1s single-hit cues that don't read
    /// as "alarm" for the speedrun / pomodoro / focus use case. Per D-030.
    static let bundledAlarmTag = "Alarm"

    /// How many times to play the end-of-countdown sound. 1 = play once
    /// naturally. N > 1 = play N times, using NSSound's delegate callback
    /// to chain replays after each finish — gives a natural ~10ms gap
    /// between iterations that reads as rhythmic for short sounds. Applied
    /// uniformly to system sounds, bundled Alarm, and user-picked custom
    /// sounds. Per D-030.
    @Published var soundPlayCount: Int {
        didSet { saveSettings() }
    }

    /// Held reference to the currently-playing NSSound so back-to-back
    /// triggers (rapid Test presses, or countdown completes during preview)
    /// stop the prior cleanly.
    private var currentSound: NSSound?

    /// Held reference to the delegate that chains repeat plays. Must live
    /// as long as the sound is playing; NSSound's delegate property is
    /// `weak`, so without our strong ref the delegate would deallocate
    /// after its enclosing scope ends and replay would never fire.
    private var soundReplayDelegate: SoundReplayDelegate?

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

    static let defaultCountdownColor = Color(red: 0.129, green: 0.129, blue: 0.129)  // #212121
    static let defaultStopwatchColor = Color(red: 0.580, green: 0.067, blue: 0.000)  // #941100
    static let defaultCountdownEndSound = bundledAlarmTag
    static let defaultSoundPlayCount = 3
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
        self.delayTickEnabled = (dict["delayTickEnabled"] as? Bool) ?? false
        self.customSoundFileName = dict["customSoundFileName"] as? String
        self.customSoundBookmark = dict["customSoundBookmark"] as? Data
        self.soundPlayCount = max(1, (dict["soundPlayCount"] as? Int) ?? TimerEngine.defaultSoundPlayCount)

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

    // MARK: - Reset to defaults

    /// Wipes persisted settings and restores all user-configurable state to
    /// factory defaults. Cancels any in-flight delay/timer. Each @Published
    /// assignment fires its didSet → saveSettings, so the final dict reflects
    /// the new defaults.
    func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        UserDefaults.standard.removeObject(forKey: legacyKeyV1)

        cancelDelay()
        countdownStartedAt = nil
        countdownRunning = false
        stopwatchStartedAt = nil
        stopwatchPausedElapsed = 0
        stopwatchElapsed = 0
        stopwatchRunning = false

        countdownTarget = 1200
        countdownPausedRemaining = 1200
        countdownRemaining = 1200
        countdownVisible = true
        stopwatchVisible = true
        precision = 1
        countdownColor = TimerEngine.defaultCountdownColor
        stopwatchColor = TimerEngine.defaultStopwatchColor
        soundEnabled = false
        countdownEndSound = TimerEngine.defaultCountdownEndSound
        delaySeconds = 3
        delayTickEnabled = false
        customSoundFileName = nil
        customSoundBookmark = nil
        soundPlayCount = TimerEngine.defaultSoundPlayCount
        saveSettings()
    }

    // MARK: - Custom sound mutators

    /// Persists a user-picked sound file's security-scoped bookmark + display
    /// name, and switches `countdownEndSound` to the custom branch.
    func setCustomSound(bookmark: Data, fileName: String) {
        customSoundBookmark = bookmark
        customSoundFileName = fileName
        countdownEndSound = TimerEngine.customSoundTag
        saveSettings()
    }

    /// Clears the custom sound and reverts `countdownEndSound` to the
    /// default system sound. Called from the menu's clear-custom affordance.
    func clearCustomSound() {
        customSoundBookmark = nil
        customSoundFileName = nil
        if countdownEndSound == TimerEngine.customSoundTag {
            countdownEndSound = TimerEngine.defaultCountdownEndSound
        }
        saveSettings()
    }

    private func playEndSound() {
        guard soundEnabled, countdownEndSound != "None" else { return }

        // Stop any prior playback (e.g. rapid-fire Test presses or back-to-back
        // countdown completes) so they don't pile up.
        currentSound?.stop()
        currentSound = nil
        soundReplayDelegate = nil

        let sound: NSSound?
        switch countdownEndSound {
        case TimerEngine.customSoundTag:
            sound = loadCustomSound()
        case TimerEngine.bundledAlarmTag:
            sound = loadBundledAlarmSound()
        default:
            sound = NSSound(named: countdownEndSound)
        }
        guard let s = sound else { return }

        let count = max(1, soundPlayCount)
        if count > 1 {
            let delegate = SoundReplayDelegate(remaining: count - 1) { [weak self] finished in
                if self?.currentSound === finished {
                    self?.currentSound = nil
                    self?.soundReplayDelegate = nil
                }
            }
            soundReplayDelegate = delegate
            s.delegate = delegate
        }
        currentSound = s
        s.play()
    }

    /// Resolves the security-scoped bookmark for the user-picked sound file,
    /// reads its bytes, and returns an NSSound. Loading into `Data` lets us
    /// release scoped access immediately — NSSound owns its own copy. Silent
    /// failure on missing/moved file or stale bookmark; user can re-pick.
    private func loadCustomSound() -> NSSound? {
        guard let bookmark = customSoundBookmark else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSSound(data: data)
    }

    /// Loads the bundled Alarm.m4a from the app bundle. `byReference: false`
    /// reads the file data eagerly so the NSSound is self-contained.
    private func loadBundledAlarmSound() -> NSSound? {
        guard let url = Bundle.main.url(forResource: "Alarm", withExtension: "m4a") else { return nil }
        return NSSound(contentsOf: url, byReference: false)
    }

    /// Soft Tink for each visible digit of the 3-2-1 delay countdown.
    /// Hardcoded sound choice — keeps v1.1 scope tight; picker can land in
    /// v1.2 if users ask for it.
    private func playDelayTick() {
        guard delayTickEnabled else { return }
        NSSound(named: "Tink")?.play()
    }

    // MARK: - Delay-start state machine (v0.3)

    private func beginDelay(for action: PendingStartAction) {
        cancelDelay()
        pendingAction = action
        delayRemaining = delaySeconds
        playDelayTick()  // tick aligned with initial digit appearing
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
            // No tick on the start moment — the timer beginning is its own cue.
        } else {
            delayRemaining = current - 1
            playDelayTick()  // tick aligned with each subsequent digit appearing
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
        var dict: [String: Any] = [
            "countdownTarget": countdownTarget,
            "countdownVisible": countdownVisible,
            "stopwatchVisible": stopwatchVisible,
            "precision": precision,
            "countdownColorHex": countdownColor.hexString ?? "",
            "stopwatchColorHex": stopwatchColor.hexString ?? "",
            "soundEnabled": soundEnabled,
            "countdownEndSound": countdownEndSound,
            "delaySeconds": delaySeconds,
            "delayTickEnabled": delayTickEnabled,
            "soundPlayCount": soundPlayCount,
        ]
        // Custom-sound entries are conditional — when nil, omit the keys
        // entirely. The whole dict is replaced on each set, so cleared
        // values don't linger from prior writes.
        if let fileName = customSoundFileName {
            dict["customSoundFileName"] = fileName
        }
        if let bookmark = customSoundBookmark {
            dict["customSoundBookmark"] = bookmark
        }
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

// MARK: - NSSound replay delegate

/// Chains N-1 replays after the initial NSSound.play() call, giving true
/// "play N times" semantics. NSSound's `delegate` is weak, so the
/// enclosing engine must hold a strong reference to this object for the
/// full playback duration — otherwise the delegate deallocates and replay
/// silently stops at the first finish callback.
final class SoundReplayDelegate: NSObject, NSSoundDelegate {
    private var remaining: Int
    private let onAllDone: (NSSound) -> Void

    init(remaining: Int, onAllDone: @escaping (NSSound) -> Void) {
        self.remaining = remaining
        self.onAllDone = onAllDone
    }

    func sound(_ sound: NSSound, didFinishPlaying flag: Bool) {
        guard flag, remaining > 0 else {
            onAllDone(sound)
            return
        }
        remaining -= 1
        sound.play()
    }
}
