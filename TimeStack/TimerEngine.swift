import Combine
import Foundation

@MainActor
final class TimerEngine: ObservableObject {

    // MARK: - User-configurable state

    @Published var countdownTarget: TimeInterval {
        didSet { saveSettings() }
    }
    @Published var countdownVisible: Bool {
        didSet { saveSettings() }
    }
    @Published var stopwatchVisible: Bool {
        didSet { saveSettings() }
    }

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
    private let displayInterval: TimeInterval = 0.05  // 50ms — smooth tenths display

    private let settingsKey = "TimeStack.settings.v1"

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        let target = (defaults["countdownTarget"] as? TimeInterval) ?? 1200  // 20:00 default
        self.countdownTarget = target
        self.countdownRemaining = target
        self.countdownPausedRemaining = target
        self.countdownVisible = (defaults["countdownVisible"] as? Bool) ?? true
        self.stopwatchVisible = (defaults["stopwatchVisible"] as? Bool) ?? true

        startDisplayLoop()
    }

    deinit {
        displayTimer?.invalidate()
    }

    // MARK: - Countdown control

    func startCountdown() {
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
        startCountdown()
        startStopwatch()
    }

    func stopBoth() {
        stopCountdown()
        stopStopwatch()
    }

    func resetBoth() {
        resetCountdown()
        resetStopwatch()
    }

    // MARK: - Display loop

    private func startDisplayLoop() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
                // Countdown finished. Stop but leave "00:00" on screen.
                countdownPausedRemaining = 0
                countdownStartedAt = nil
                countdownRunning = false
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
        ]
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }
}
