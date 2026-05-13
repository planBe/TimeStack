import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var overlay: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            countdownSection
            Divider()
            stopwatchSection
            Divider()
            bothSection
            Divider()
            displaySection
            Divider()

            Button("Quit TimeStack") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 280)
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Countdown")
            HStack {
                Text(TimeFormatter.format(engine.countdownRemaining))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 88, alignment: .leading)
                Spacer()
                Button(engine.countdownRunning ? "Pause" : "Start") {
                    if engine.countdownRunning {
                        engine.stopCountdown()
                    } else {
                        engine.startCountdown()
                    }
                }
                Button("Reset") { engine.resetCountdown() }
            }
            .padding(.horizontal, 12)

            HStack {
                Text("Target")
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: Binding(
                        get: { Int(engine.countdownTarget / 60) },
                        set: { newValue in
                            engine.countdownTarget = TimeInterval(newValue * 60)
                            engine.resetCountdown()
                        }
                    ),
                    in: 1...180
                ) {
                    Text("\(Int(engine.countdownTarget / 60)) min")
                        .frame(width: 64, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .font(.caption)
        }
    }

    // MARK: - Stopwatch

    private var stopwatchSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Stopwatch")
            HStack {
                Text(TimeFormatter.format(engine.stopwatchElapsed))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 88, alignment: .leading)
                Spacer()
                Button(engine.stopwatchRunning ? "Pause" : "Start") {
                    if engine.stopwatchRunning {
                        engine.stopStopwatch()
                    } else {
                        engine.startStopwatch()
                    }
                }
                Button("Reset") { engine.resetStopwatch() }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Both

    private var bothSection: some View {
        HStack {
            Button("Start Both") { engine.startBoth() }
            Button("Stop Both") { engine.stopBoth() }
            Button("Reset Both") { engine.resetBoth() }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Display")
            Toggle("Show countdown", isOn: $engine.countdownVisible)
                .padding(.horizontal, 12)
            Toggle("Show stopwatch", isOn: $engine.stopwatchVisible)
                .padding(.horizontal, 12)
            Toggle("Lock (click-through)", isOn: $overlay.isLocked)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            HStack {
                Text("Opacity")
                    .foregroundStyle(.secondary)
                Slider(value: $overlay.alpha, in: 0.2...1.0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .font(.caption)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
