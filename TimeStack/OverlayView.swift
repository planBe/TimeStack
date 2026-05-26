import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var overlay: OverlayController

    var body: some View {
        GeometryReader { geo in
            // Font fits BOTH width and height budgets — pick whichever is more
            // constraining so the timer text always fits the card without
            // clipping. Width budget: "00:00.0" is 7 chars at monospaced width
            // ≈ 0.6× the font size, plus card chrome. Height budget: each card
            // gets ~half the window height (minus chrome), and text is ~55%
            // of card height after the header.
            let visibleCount = max(1, (engine.countdownVisible ? 1 : 0) + (engine.stopwatchVisible ? 1 : 0))
            let outerChrome: CGFloat = 32  // .padding(10) + .padding(6) doubled
            let widthBudget = max(0, geo.size.width - outerChrome - 28) / 4.2
            let cardHeight = max(0, (geo.size.height - outerChrome - 10 * CGFloat(visibleCount - 1)) / CGFloat(visibleCount))
            // Card chrome (post v0.4-tight): TimerPanel .padding(.vertical, 4)
            // × 2 + header (≤14pt cap) + spacing (~2pt) = ~24pt. Divide by 1.2
            // to account for monospaced text's intrinsic line-height — without
            // this multiplier, SwiftUI's .minimumScaleFactor kicks in to
            // shrink the displayed text below the nominal font size. Header
            // is dynamic per TimerPanel's `fontSize * 0.20` clamped [9,14] —
            // budget uses the 14pt cap as the conservative worst case.
            let heightBudget = max(0, cardHeight - 24) / 1.2
            // Floor at 28pt: at small windows the time stays glance-readable.
            // Header gently shrinks toward 9pt at the floor (~3:1 hierarchy),
            // grows toward 14pt at large fontSize (~20:1 for max readability).
            let fontSize = max(28, min(widthBudget, heightBudget))
            contentBody
                .environment(\.timerFontSize, fontSize)
                .onAppear { syncWindowAspect() }
        }
    }

    /// Called once on appear to align the window with the saved visibility
    /// state. Visibility changes thereafter route through the menu's custom
    /// Binding setters (or × button onClose closures), which resize the
    /// window BEFORE mutating engine state — eliminating the SwiftUI
    /// `.onChange` race that left stale GeometryReader dimensions and
    /// clipped content.
    private func syncWindowAspect() {
        let count = (engine.countdownVisible ? 1 : 0) + (engine.stopwatchVisible ? 1 : 0)
        overlay.updateAspectAndSize(for: count)
    }

    private var contentBody: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 10) {
                if engine.countdownVisible {
                    TimerPanel(
                        label: "Countdown",
                        time: engine.countdownRemaining,
                        isRunning: engine.countdownRunning,
                        tint: engine.countdownColor,
                        precision: engine.precision,
                        showCloseButton: !overlay.isLocked,
                        onClose: { hideCountdown() },
                        timeView: AnyView(
                            EditableCountdownView()
                                .environmentObject(engine)
                                .environmentObject(overlay)
                        )
                    )
                    .frame(maxHeight: .infinity)
                }
                if engine.stopwatchVisible {
                    TimerPanel(
                        label: "Stopwatch",
                        time: engine.stopwatchElapsed,
                        isRunning: engine.stopwatchRunning,
                        tint: engine.stopwatchColor,
                        precision: engine.precision,
                        showCloseButton: !overlay.isLocked,
                        onClose: { hideStopwatch() },
                        timeView: stopwatchTimeView
                    )
                    .frame(maxHeight: .infinity)
                }
                if !engine.countdownVisible && !engine.stopwatchVisible {
                    emptyState
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
            )
            .padding(6)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    /// Resize-first × handlers: window snaps to new aspect/size SYNCHRONOUSLY
    /// before the engine's @Published visibility flag flips, so SwiftUI's
    /// GeometryReader reads the new window dimensions on its re-render and
    /// content lays out correctly. (Reversing the order — mutate then
    /// resize — leaves GeometryReader reading stale OLD dimensions and
    /// content gets clipped.)
    private func hideCountdown() {
        overlay.updateAspectAndSize(for: engine.stopwatchVisible ? 1 : 0)
        engine.countdownVisible = false
    }

    private func hideStopwatch() {
        overlay.updateAspectAndSize(for: engine.countdownVisible ? 1 : 0)
        engine.stopwatchVisible = false
    }

    /// Stopwatch panel's time-area override: shows the big delay digit when a delay-start
    /// is pending for this timer (alone or via Both); otherwise nil → falls back to TimerPanel's
    /// default formatted text.
    private var stopwatchTimeView: AnyView? {
        guard let delay = engine.delayRemaining else { return nil }
        switch engine.pendingAction {
        case .stopwatch, .both:
            return AnyView(DelayDisplayView(value: delay, tint: engine.stopwatchColor))
        default:
            return nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "stopwatch")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("Both timers hidden")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Environment key for window-driven font scaling

struct TimerFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 54
}

extension EnvironmentValues {
    var timerFontSize: CGFloat {
        get { self[TimerFontSizeKey.self] }
        set { self[TimerFontSizeKey.self] = newValue }
    }
}

// MARK: - Editable countdown (tap-to-edit on the overlay panel)

private struct EditableCountdownView: View {
    @EnvironmentObject var engine: TimerEngine
    @EnvironmentObject var overlay: OverlayController
    @Environment(\.timerFontSize) private var fontSize
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if let delay = engine.delayRemaining, isCountdownPending {
                DelayDisplayView(value: delay, tint: engine.countdownColor)
            } else if isEditing {
                TextField("MM:SS", text: $editText)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(engine.countdownColor)
                    .monospacedDigit()
                    .onSubmit { commit() }
                    .onChange(of: fieldFocused) { focused in
                        if !focused { commit() }
                    }
                    .onAppear { fieldFocused = true }
            } else {
                Text(TimeFormatter.format(engine.countdownRemaining, precision: engine.precision))
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(engine.countdownColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var isCountdownPending: Bool {
        engine.pendingAction == .countdown || engine.pendingAction == .both
    }

    private func beginEditing() {
        guard !engine.countdownRunning, !overlay.isLocked, engine.delayRemaining == nil else { return }
        editText = formatForEditing(engine.countdownTarget)
        isEditing = true
    }

    private func commit() {
        if let parsed = parseTime(editText) {
            engine.countdownTarget = parsed
            engine.resetCountdown()
        }
        isEditing = false
    }

    private func formatForEditing(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func parseTime(_ text: String) -> TimeInterval? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ":")
        if parts.count == 2 {
            guard let m = Int(parts[0]), let s = Int(parts[1]),
                  m >= 0, s >= 0, s < 60, m * 60 + s > 0 else { return nil }
            return TimeInterval(m * 60 + s)
        }
        if parts.count == 1, let m = Int(cleaned), m > 0 {
            return TimeInterval(m * 60)
        }
        return nil
    }
}

// MARK: - Delay-start big-digit display (3, 2, 1, GO)

fileprivate struct DelayDisplayView: View {
    let value: Int
    let tint: Color
    @Environment(\.timerFontSize) private var fontSize

    var body: some View {
        // Delay digit ~10% larger than regular timer text for visual emphasis
        Text("\(value)")
            .font(.system(size: fontSize * 1.1, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(.opacity)
    }
}
