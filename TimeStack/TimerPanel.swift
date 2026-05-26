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

    @Environment(\.timerFontSize) private var fontSize

    var body: some View {
        // Gentle header scaling derived from timerFontSize. At fontSize=55
        // (default) this resolves to exactly 11pt — matching pre-v1.1
        // baseline. At small windows (fontSize ~28) shrinks to 9pt floor for
        // more timer breathing room; at large windows grows to a 14pt cap so
        // the header isn't visually swamped by giant timer text. Dot and ×
        // scale proportionally so the row reads as one cohesive element.
        let headerSize = min(14, max(9, fontSize * 0.20))
        let dotSize = headerSize * 0.55
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? tint : .secondary.opacity(0.5))
                    .frame(width: dotSize, height: dotSize)
                Text(label.uppercased())
                    .font(.system(size: headerSize, design: .rounded).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if showCloseButton, let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: headerSize, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Hide \(label.lowercased())")
                }
            }
            if let timeView {
                timeView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(TimeFormatter.format(time, precision: precision))
                    .font(.system(size: fontSize, weight: .medium, design: .monospaced))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(adaptiveCardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Card background flips between a light and dark tint based on the text
    /// color's perceived luminance. Without this, dark user-picked text
    /// (e.g. #212121) is invisible on a dark card and light text (e.g. system
    /// yellow) washes out on a light card.
    private var adaptiveCardBackground: Color {
        let ns = NSColor(tint).usingColorSpace(.sRGB) ?? NSColor(tint)
        // ITU-R BT.601 luma weights — perceptual approximation of brightness
        let luma = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return luma < 0.5 ? Color.white.opacity(0.20) : Color.black.opacity(0.28)
    }
}
