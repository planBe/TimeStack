import SwiftUI

struct OverlayView: View {
    @EnvironmentObject var engine: TimerEngine

    var body: some View {
        VStack(spacing: 8) {
            if engine.countdownVisible {
                TimerPanel(
                    label: "Countdown",
                    time: engine.countdownRemaining,
                    isRunning: engine.countdownRunning,
                    tint: countdownTint
                )
            }
            if engine.stopwatchVisible {
                TimerPanel(
                    label: "Stopwatch",
                    time: engine.stopwatchElapsed,
                    isRunning: engine.stopwatchRunning,
                    tint: .green
                )
            }
            if !engine.countdownVisible && !engine.stopwatchVisible {
                emptyState
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(6)
    }

    private var countdownTint: Color {
        if engine.countdownRemaining <= 0 { return .orange }
        if engine.countdownRemaining < 60 { return .yellow }
        return .blue
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "stopwatch")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Both timers hidden")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Toggle from the menu bar")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
    }
}
