import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var overlay: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brandingHeader
            Divider()
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

    // MARK: - Branding header

    private var brandingHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "stopwatch")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("timeStack")
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
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
            colorRow(label: "Countdown color", color: $engine.countdownColor)
            colorRow(label: "Stopwatch color", color: $engine.stopwatchColor)
                .padding(.bottom, 4)
        }
    }

    private func colorRow(label: String, color: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            ColorSwatchButton(color: color)
        }
        .padding(.horizontal, 12)
        .font(.caption)
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

// MARK: - Color swatch button → opens NSColorPanel

/// A SwiftUI swatch button that opens the system NSColorPanel on tap.
/// We use NSColorPanel (a real Apple-managed top-level window) instead of
/// NSColorWell's popover because popovers can't reliably anchor inside a
/// MenuBarExtra window after app-switching. NSColorPanel handles activation
/// correctly in all states.
private struct ColorSwatchButton: View {
    @Binding var color: Color

    var body: some View {
        Button {
            ColorPanelCoordinator.shared.present(initialColor: color) { newColor in
                color = newColor
            }
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(.secondary.opacity(0.4), lineWidth: 0.5)
                )
                .frame(width: 44, height: 22)
        }
        .buttonStyle(.plain)
    }
}

/// Bridges between transient SwiftUI swatch taps and the long-lived
/// NSColorPanel.shared singleton. Holds the current color-change callback
/// so target/action callbacks from NSColorPanel route to the right @Binding.
@MainActor
private final class ColorPanelCoordinator: NSObject {
    static let shared = ColorPanelCoordinator()

    private var onChange: ((Color) -> Void)?

    private override init() { super.init() }

    func present(initialColor: Color, onChange: @escaping (Color) -> Void) {
        self.onChange = onChange
        let panel = NSColorPanel.shared
        panel.color = NSColor(initialColor)
        panel.showsAlpha = false
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        onChange?(Color(sender.color))
    }
}
