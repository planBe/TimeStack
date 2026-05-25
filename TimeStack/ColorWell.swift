import SwiftUI
import AppKit

/// A SwiftUI swatch button that opens the system NSColorPanel on tap.
/// NSColorPanel is a real Apple-managed top-level window that handles
/// activation correctly inside LSUIElement (menu bar agent) apps —
/// SwiftUI's `ColorPicker` and `NSColorWell.expanded` both rely on
/// popover anchoring inside the MenuBarExtra window, which silently
/// fails after the user app-switches away and back.
struct ColorSwatchButton: View {
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
final class ColorPanelCoordinator: NSObject {
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
