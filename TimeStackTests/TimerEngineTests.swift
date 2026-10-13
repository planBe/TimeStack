import Foundation
import Testing

/// The two timers are the product, so their arithmetic is pinned against a
/// clock the test moves by hand and a throwaway defaults suite. No test waits
/// on real time or touches the user's settings.
@MainActor
struct TimerEngineTests {

    /// A clock that only moves when a test says so. A display-loop tick that
    /// fires on its own mid-test reads the same time and changes nothing.
    private final class Clock {
        var t = Date(timeIntervalSince1970: 1_000_000)
        func advance(_ seconds: TimeInterval) { t += seconds }
    }

    /// One suite per test function, emptied before use (a fresh UUID per run
    /// would leave a new plist in ~/Library/Preferences every run).
    private func makeDefaults(_ test: String) -> UserDefaults {
        let name = "TimeStackTests.\(test.prefix { $0 != "(" })"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    /// An engine with a 60 s countdown, no start delay and no end sound.
    private func makeEngine(_ defaults: UserDefaults? = nil, test: String = #function) -> (TimerEngine, Clock, UserDefaults) {
        let d = defaults ?? makeDefaults(test)
        let clock = Clock()
        let engine = TimerEngine(defaults: d, now: { clock.t })
        engine.soundEnabled = false
        engine.delaySeconds = 0
        engine.countdownTarget = 60
        engine.resetCountdown()
        return (engine, clock, d)
    }

    // MARK: - Pure arithmetic

    @Test("Countdown remaining is what was left minus the time since resuming")
    func countdownArithmetic() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        #expect(TimerEngine.countdownLeft(pausedRemaining: 60, startedAt: t0, now: t0) == 60)
        #expect(TimerEngine.countdownLeft(pausedRemaining: 60, startedAt: t0, now: t0 + 12.5) == 47.5)
        #expect(TimerEngine.countdownLeft(pausedRemaining: 2, startedAt: t0, now: t0 + 3) == -1)
    }

    @Test("Stopwatch elapsed is the banked time plus the time since resuming")
    func stopwatchArithmetic() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        #expect(TimerEngine.stopwatchTotal(pausedElapsed: 0, startedAt: t0, now: t0) == 0)
        #expect(TimerEngine.stopwatchTotal(pausedElapsed: 5, startedAt: t0, now: t0 + 2.25) == 7.25)
    }

    @Test("Resumable means a countdown part-way through or a stopwatch with time on it", arguments: [
        (60.0, 0.0, false),   // untouched
        (59.5, 0.0, true),    // countdown paused part-way
        (0.0, 0.0, false),    // countdown finished: nothing to resume
        (60.0, 0.01, true),   // stopwatch has time
        (0.0, 3.0, true),     // finished countdown, stopwatch has time
    ])
    func resumable(remaining: Double, elapsed: Double, expected: Bool) {
        #expect(TimerEngine.hasResumableState(
            countdownRemaining: remaining, countdownTarget: 60, stopwatchElapsed: elapsed
        ) == expected)
    }

    // MARK: - The engine against the clock

    @Test("Countdown runs, holds while paused, and resumes from where it stopped")
    func countdownPauseResume() {
        let (engine, clock, _) = makeEngine()
        engine.startCountdown()
        #expect(engine.countdownRunning)
        clock.advance(10)
        engine.tick()
        #expect(engine.countdownRemaining == 50)

        engine.stopCountdown()
        clock.advance(100)
        engine.tick()
        #expect(!engine.countdownRunning)
        #expect(engine.countdownRemaining == 50)

        engine.startCountdown()
        clock.advance(5)
        engine.tick()
        #expect(engine.countdownRemaining == 45)
    }

    @Test("Countdown stops at zero, and the next start begins a full countdown")
    func countdownFinishes() {
        let (engine, clock, _) = makeEngine()
        engine.startCountdown()
        clock.advance(61)
        engine.tick()
        #expect(engine.countdownRemaining == 0)
        #expect(!engine.countdownRunning)

        engine.startCountdown()
        engine.tick()
        #expect(engine.countdownRunning)
        #expect(engine.countdownRemaining == 60)
    }

    @Test("Stopwatch counts, holds while paused, resumes, and resets to zero")
    func stopwatchPauseResume() {
        let (engine, clock, _) = makeEngine()
        engine.startStopwatch()
        clock.advance(3)
        engine.tick()
        #expect(engine.stopwatchElapsed == 3)

        engine.stopStopwatch()
        clock.advance(50)
        engine.tick()
        #expect(engine.stopwatchElapsed == 3)

        engine.startStopwatch()
        clock.advance(1.5)
        engine.tick()
        #expect(engine.stopwatchElapsed == 4.5)

        engine.resetStopwatch()
        #expect(engine.stopwatchElapsed == 0)
        #expect(!engine.stopwatchRunning)
    }

    @Test("Pause Both flips to Resume Both only when there is something to resume")
    func bothResumable() {
        let (engine, clock, _) = makeEngine()
        #expect(!engine.bothHasResumableState)

        engine.startBoth()
        clock.advance(1)
        engine.tick()
        engine.stopBoth()
        #expect(engine.bothHasResumableState)

        engine.resumeBoth()
        #expect(engine.countdownRunning && engine.stopwatchRunning)
        clock.advance(2)
        engine.tick()
        #expect(engine.countdownRemaining == 57)
        #expect(engine.stopwatchElapsed == 3)

        engine.resetBoth()
        #expect(!engine.bothHasResumableState)
    }

    @Test("A start delay holds the timers until it runs out; pressing again cancels it")
    func startDelay() {
        let (engine, _, _) = makeEngine()
        engine.delaySeconds = 3
        engine.startCountdown()
        #expect(engine.pendingAction == .countdown)
        #expect(engine.delayRemaining == 3)
        #expect(!engine.countdownRunning)

        engine.startCountdown()
        #expect(engine.pendingAction == nil)
        #expect(engine.delayRemaining == nil)
        #expect(!engine.countdownRunning)
    }

    // MARK: - The 20 Hz display loop runs only while a timer does

    @Test("The display loop is off at launch and through a start delay")
    func displayLoopIdle() {
        // A bare engine, not makeEngine(): its resetCountdown() runs the
        // flags' didSet, which would stop a loop init had wrongly started.
        let bare = TimerEngine(defaults: makeDefaults(#function), now: { Date(timeIntervalSince1970: 0) })
        #expect(!bare.displayLoopRunning)

        let (engine, _, _) = makeEngine()
        #expect(!engine.displayLoopRunning)

        engine.delaySeconds = 3
        engine.startBoth()
        #expect(engine.delayRemaining == 3)
        #expect(!engine.displayLoopRunning)

        engine.startBoth()  // pressing again cancels the delay
        #expect(engine.delayRemaining == nil)
        #expect(!engine.displayLoopRunning)
    }

    @Test("The display loop runs while either timer runs and stops when both pause")
    func displayLoopFollowsTimers() {
        let (engine, _, _) = makeEngine()
        engine.startCountdown()
        #expect(engine.displayLoopRunning)
        engine.startStopwatch()
        engine.stopCountdown()
        #expect(engine.displayLoopRunning)
        engine.stopStopwatch()
        #expect(!engine.displayLoopRunning)

        engine.resumeBoth()
        #expect(engine.displayLoopRunning)
        engine.stopBoth()
        #expect(!engine.displayLoopRunning)

        engine.startBoth()
        engine.resetBoth()
        #expect(!engine.displayLoopRunning)

        engine.startStopwatch()
        engine.resetToDefaults()
        #expect(!engine.displayLoopRunning)
    }

    @Test("A countdown that runs out stops the loop, unless the stopwatch is still going")
    func displayLoopAfterFinish() {
        let (engine, clock, _) = makeEngine()
        engine.startCountdown()
        clock.advance(61)
        engine.tick()
        #expect(!engine.countdownRunning)
        #expect(!engine.displayLoopRunning)

        engine.startBoth()
        clock.advance(61)
        engine.tick()
        #expect(!engine.countdownRunning)
        #expect(engine.stopwatchRunning)
        #expect(engine.displayLoopRunning)
        #expect(engine.stopwatchElapsed == 61)
    }

    // MARK: - Settings go to the injected suite

    @Test("Settings save to the injected suite and load back from it")
    func settingsRoundTrip() {
        let (engine, _, d) = makeEngine()
        engine.precision = 2
        engine.countdownTarget = 300
        let saved = d.dictionary(forKey: "TimeStack.settings.v2")
        #expect(saved?["precision"] as? Int == 2)
        #expect(saved?["countdownTarget"] as? TimeInterval == 300)

        let reloaded = TimerEngine(defaults: d, now: { Date(timeIntervalSince1970: 0) })
        #expect(reloaded.precision == 2)
        #expect(reloaded.countdownTarget == 300)
        #expect(reloaded.countdownRemaining == 300)
    }

    @Test("A v1 settings dict is read when there is no v2 one")
    func legacySettings() {
        let d = makeDefaults(#function)
        let v1: [String: Any] = ["countdownTarget": 90.0, "stopwatchVisible": false]
        d.set(v1, forKey: "TimeStack.settings.v1")
        let engine = TimerEngine(defaults: d)
        #expect(engine.countdownTarget == 90)
        #expect(engine.countdownRemaining == 90)
        #expect(!engine.stopwatchVisible)
    }

    @Test("Reset to defaults stops the timers and rewrites the suite with factory values")
    func resetToDefaults() {
        let (engine, clock, d) = makeEngine()
        engine.precision = 2
        d.set(["countdownTarget": 5.0], forKey: "TimeStack.settings.v1")
        engine.startBoth()
        clock.advance(4)
        engine.tick()

        engine.resetToDefaults()
        #expect(!engine.countdownRunning && !engine.stopwatchRunning)
        #expect(engine.stopwatchElapsed == 0)
        #expect(engine.countdownRemaining == 1200)
        #expect(engine.precision == 1)
        #expect(d.dictionary(forKey: "TimeStack.settings.v1") == nil)
        #expect(d.dictionary(forKey: "TimeStack.settings.v2")?["precision"] as? Int == 1)
    }
}
