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
            styleSection
            Divider()
            soundSection
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
                Text(TimeFormatter.format(engine.countdownRemaining, precision: engine.precision))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Button(countdownActionLabel) {
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
                Text(TimeFormatter.format(engine.stopwatchElapsed, precision: engine.precision))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 100, alignment: .leading)
                Spacer()
                Button(stopwatchActionLabel) {
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
            Button(bothActionLabel) { engine.startBoth() }
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
            .padding(.bottom, 4)
            .font(.caption)

            HStack {
                Text("Precision")
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $engine.precision) {
                    Text("Seconds").tag(0)
                    Text("Tenths").tag(1)
                    Text("Hundredths").tag(2)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .font(.caption)

            HStack {
                Text("Start delay")
                    .foregroundStyle(.secondary)
                Spacer()
                Stepper(
                    value: $engine.delaySeconds,
                    in: 0...10
                ) {
                    Text(engine.delaySeconds == 0 ? "Off" : "\(engine.delaySeconds) sec")
                        .frame(width: 64, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .font(.caption)
        }
    }

    // MARK: - Style

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Style")
            ColorPicker("Countdown color", selection: $engine.countdownColor, supportsOpacity: false)
                .padding(.horizontal, 12)
                .font(.caption)
            ColorPicker("Stopwatch color", selection: $engine.stopwatchColor, supportsOpacity: false)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .font(.caption)
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Sound")
            Toggle("Play sound at countdown 0", isOn: $engine.soundEnabled)
                .padding(.horizontal, 12)
                .font(.caption)

            HStack {
                Picker("", selection: $engine.countdownEndSound) {
                    Text("None").tag("None")
                    ForEach(TimerEngine.availableSystemSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!engine.soundEnabled)

                Button("Test") {
                    engine.previewCurrentSound()
                }
                .disabled(!engine.soundEnabled || engine.countdownEndSound == "None")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .font(.caption)
        }
    }

    // MARK: - Delay-aware button labels

    private var countdownActionLabel: String {
        if engine.delayRemaining != nil,
           engine.pendingAction == .countdown || engine.pendingAction == .both {
            return "Cancel"
        }
        return engine.countdownRunning ? "Pause" : "Start"
    }

    private var stopwatchActionLabel: String {
        if engine.delayRemaining != nil,
           engine.pendingAction == .stopwatch || engine.pendingAction == .both {
            return "Cancel"
        }
        return engine.stopwatchRunning ? "Pause" : "Start"
    }

    private var bothActionLabel: String {
        engine.delayRemaining != nil && engine.pendingAction == .both ? "Cancel" : "Start Both"
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
