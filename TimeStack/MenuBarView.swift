import SwiftUI
import AppKit
import UniformTypeIdentifiers

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

            Button("Reset to Defaults…") {
                confirmResetToDefaults()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.08))

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

    private func confirmResetToDefaults() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reset TimeStack to defaults?"
        alert.informativeText = "Your custom colors, window position and size, transparency, sound choice, delay-start, and other preferences will be restored to factory defaults. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        // Resize window FIRST to both-visible aspect (reset restores both),
        // then mutate engine + overlay state. Same race-free ordering as the
        // visibility toggles.
        overlay.updateAspectAndSize(for: 2)
        engine.resetToDefaults()
        overlay.resetToDefaults()
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
            Button(mainBothLabel) { mainBothAction() }
            Button("Reset Both") { engine.resetBoth() }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.08))
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("Display")
            Toggle("Show countdown", isOn: countdownVisibleBinding)
                .padding(.horizontal, 12)
            Toggle("Show stopwatch", isOn: stopwatchVisibleBinding)
                .padding(.horizontal, 12)
            Toggle("Lock (click-through)", isOn: $overlay.isLocked)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)

            HStack {
                Text("Opacity")
                    .foregroundStyle(.secondary)
                Slider(value: $overlay.alpha, in: 0.2...1.0)
                Text("\(Int(overlay.alpha * 100))%")
                    .frame(width: 36, alignment: .trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.08))
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
                    Text("Alarm").tag(TimerEngine.bundledAlarmTag)
                    Text("Siren").tag(TimerEngine.bundledSirenTag)
                    Divider()
                    ForEach(TimerEngine.availableSystemSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    Divider()
                    Text("Custom…").tag(TimerEngine.customSoundTag)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!engine.soundEnabled)
                .onChange(of: engine.countdownEndSound) { newValue in
                    // Auto-prompt for a file the first time the user picks
                    // Custom and no bookmark is set yet. Subsequent
                    // selections of Custom (after a file is picked) just
                    // switch playback; the Choose button below handles swaps.
                    if newValue == TimerEngine.customSoundTag,
                       engine.customSoundFileName == nil {
                        promptForCustomSound()
                    }
                }

                Button("Test") {
                    engine.previewCurrentSound()
                }
                .disabled(testButtonDisabled)
            }
            .padding(.horizontal, 12)
            .font(.caption)

            HStack {
                Text("Play")
                    .foregroundStyle(.secondary)
                Picker("", selection: $engine.soundPlayCount) {
                    Text("Once").tag(1)
                    Text("3×").tag(3)
                    Text("5×").tag(5)
                    Text("10×").tag(10)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!engine.soundEnabled || engine.countdownEndSound == "None")
                Spacer()
            }
            .padding(.horizontal, 12)
            .font(.caption)

            if engine.countdownEndSound == TimerEngine.customSoundTag {
                HStack(spacing: 6) {
                    Text(engine.customSoundFileName ?? "(no file selected)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose…") { promptForCustomSound() }
                        .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .font(.caption)
            }

            Toggle("Tick during 3-2-1 delay", isOn: $engine.delayTickEnabled)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .font(.caption)
        }
    }

    private var testButtonDisabled: Bool {
        if !engine.soundEnabled { return true }
        if engine.countdownEndSound == "None" { return true }
        if engine.countdownEndSound == TimerEngine.customSoundTag,
           engine.customSoundFileName == nil { return true }
        return false
    }

    /// Presents NSOpenPanel filtered to audio files, creates a security-scoped
    /// bookmark on selection, and hands both off to the engine. NSApp.activate
    /// is needed because LSUIElement (menu-bar agent) apps don't auto-foreground
    /// — without it, the file panel can open behind other windows.
    private func promptForCustomSound() {
        let panel = NSOpenPanel()
        panel.title = "Choose Sound"
        panel.message = "Pick an audio file to play at countdown 0."
        panel.prompt = "Choose"
        panel.allowedContentTypes = [UTType.audio]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            engine.setCustomSound(bookmark: bookmark, fileName: url.lastPathComponent)
        } catch {
            // Bookmark creation failure is rare (typically only for files on
            // unsupported volumes). Silent in v1.1 — user can retry.
        }
    }

    // MARK: - Resize-first visibility bindings

    /// Custom Binding for the "Show countdown" toggle. When toggled, the
    /// window aspect + size are updated SYNCHRONOUSLY before the engine's
    /// visibility flag flips, so SwiftUI's next render pass uses the new
    /// window dimensions and content lays out correctly. (Standard
    /// `$engine.countdownVisible` would mutate first → SwiftUI re-renders
    /// against old window size → content clips when window resizes after.)
    private var countdownVisibleBinding: Binding<Bool> {
        Binding(
            get: { engine.countdownVisible },
            set: { newValue in
                let count = (newValue ? 1 : 0) + (engine.stopwatchVisible ? 1 : 0)
                overlay.updateAspectAndSize(for: count)
                engine.countdownVisible = newValue
            }
        )
    }

    private var stopwatchVisibleBinding: Binding<Bool> {
        Binding(
            get: { engine.stopwatchVisible },
            set: { newValue in
                let count = (engine.countdownVisible ? 1 : 0) + (newValue ? 1 : 0)
                overlay.updateAspectAndSize(for: count)
                engine.stopwatchVisible = newValue
            }
        )
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

    /// Four-state label for the single main "Both" button (mirrors the
    /// per-timer Start/Pause toggle pattern with an added Resume state):
    /// - "Cancel" during the 3-2-1 delay phase
    /// - "Pause Both" when at least one timer is running
    /// - "Resume Both" when stopped with elapsed/remaining state to resume from
    /// - "Start Both" on a fresh / just-reset state
    private var mainBothLabel: String {
        if engine.delayRemaining != nil, engine.pendingAction == .both { return "Cancel" }
        if engine.countdownRunning || engine.stopwatchRunning { return "Pause Both" }
        if engine.bothHasResumableState { return "Resume Both" }
        return "Start Both"
    }

    private func mainBothAction() {
        // Cancel during delay: startBoth's first guard handles cancelDelay().
        if engine.delayRemaining != nil, engine.pendingAction == .both {
            engine.startBoth()
            return
        }
        if engine.countdownRunning || engine.stopwatchRunning {
            engine.stopBoth()
            return
        }
        if engine.bothHasResumableState {
            engine.resumeBoth()
            return
        }
        engine.startBoth()
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

