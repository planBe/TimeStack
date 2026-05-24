import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayController: NSObject, ObservableObject, NSWindowDelegate {

    // MARK: - User-configurable overlay state

    @Published var alpha: CGFloat {
        didSet {
            window?.alphaValue = alpha
            saveSettings()
        }
    }
    @Published var isLocked: Bool {
        didSet {
            window?.ignoresMouseEvents = isLocked
            saveSettings()
        }
    }

    // MARK: - Internal

    private var window: NSPanel?
    private let settingsKey = "TimeStack.overlay.v1"

    // MARK: - Init

    override init() {
        let defaults = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        self.alpha = (defaults["alpha"] as? CGFloat) ?? 0.9
        self.isLocked = (defaults["isLocked"] as? Bool) ?? false
        super.init()
    }

    // MARK: - Window lifecycle

    /// Create and show the floating overlay panel containing the given SwiftUI content.
    func showOverlay<Content: View>(@ViewBuilder content: () -> Content) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let frame = preferredInitialFrame()

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = isLocked
        panel.alphaValue = alpha
        panel.minSize = NSSize(width: 160, height: 100)

        let hosting = NSHostingView(rootView: AnyView(content()))
        panel.contentView = hosting

        panel.delegate = self
        panel.orderFrontRegardless()

        self.window = panel
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in saveFrame() }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in saveFrame() }
    }

    // MARK: - Persistence

    private func saveFrame() {
        guard let frame = window?.frame else { return }
        var dict = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        dict["frameX"] = frame.origin.x
        dict["frameY"] = frame.origin.y
        dict["frameW"] = frame.size.width
        dict["frameH"] = frame.size.height
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }

    private func loadSavedFrame() -> CGRect? {
        let dict = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        guard let x = dict["frameX"] as? CGFloat,
              let y = dict["frameY"] as? CGFloat,
              let w = dict["frameW"] as? CGFloat,
              let h = dict["frameH"] as? CGFloat
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Returns a saved frame only if it still falls on a connected screen;
    /// otherwise centers a default-sized panel on the main screen. Handles the
    /// monitor-unplugged case so the overlay never lands invisibly off-screen.
    private func preferredInitialFrame() -> CGRect {
        let defaultSize = CGSize(width: 220, height: 240)
        if let saved = loadSavedFrame(), isFrameVisible(saved) {
            return saved
        }
        guard let screen = NSScreen.main else {
            return CGRect(origin: CGPoint(x: 100, y: 100), size: defaultSize)
        }
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.midX - defaultSize.width / 2,
            y: visible.midY - defaultSize.height / 2,
            width: defaultSize.width,
            height: defaultSize.height
        )
    }

    private func isFrameVisible(_ frame: CGRect) -> Bool {
        NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    private func saveSettings() {
        var dict = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        dict["alpha"] = alpha
        dict["isLocked"] = isLocked
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }
}
