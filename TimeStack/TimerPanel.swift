import SwiftUI

struct TimerPanel: View {
    let label: String
    let time: TimeInterval
    let isRunning: Bool
    let tint: Color
    let precision: Int
    var showCloseButton: Bool = false
    var onClose: (() -> Void)? = nil
    var timeView: AnyView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? tint : .secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if showCloseButton, let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Hide \(label.lowercased())")
                }
            }
            if let timeView {
                timeView
            } else {
                Text(TimeFormatter.format(time, precision: precision))
                    .font(.system(size: 36, weight: .medium, design: .monospaced))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
