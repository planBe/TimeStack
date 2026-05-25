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

    /// Click handler bound to the lock-window's SwiftUI button (always
    /// clickable, even when the main overlay is in click-through mode).
    func toggleLockFromCorner() {
        isLocked.toggle()
    }

    /// Adjusts the panel's aspect ratio and animates a resize when the user
    /// hides/shows timers. Width stays put; height is recomputed from the
    /// new aspect. Top-anchored (origin.y compensates) so the window doesn't
    /// visually jump down on shrink. Called from OverlayView on visibility
    /// changes.
    func updateAspectAndSize(for visibleCount: Int) {
        guard let window else { return }

        // Aspect tuned to fit visible cards comfortably:
        //   2 cards: 8:7  (current default — slightly taller than wide)
        //   1 card:  8:4 (2:1 — wider than tall, single card)
        //   0 cards: 8:3 (empty state, short)
        let (w, h): (CGFloat, CGFloat) = {
            switch visibleCount {
            case 2: return (8, 7)
            case 1: return (8, 4)
            default: return (8, 3)
            }
        }()
        let aspect = NSSize(width: w, height: h)
        window.aspectRatio = aspect
        window.contentAspectRatio = aspect

        // Resize: keep current width, derive new height from aspect, anchor
        // top edge (NSWindow origin is bottom-left so origin.y adjusts).
        var frame = window.frame
        let newHeight = frame.size.width * h / w
        let deltaHeight = frame.size.height - newHeight
        guard abs(deltaHeight) > 0.5 else { return }
        frame.size.height = newHeight
        frame.origin.y += deltaHeight
        window.setFrame(frame, display: true, animate: true)
        positionLockWindow()
    }

    // MARK: - Internal

    var window: NSPanel?
    private var lockWindow: NSPanel?
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

        // Wrap NSHostingView in a NoIntrinsicSizeView container — explicitly
        // returns noIntrinsicMetric so SwiftUI's intrinsic size never propagates
        // up to override the panel's min/max. (Plain NSView still propagates
        // intrinsic size through its constraints to the hosting view child.)
        let hosting = NSHostingView(rootView: AnyView(content()))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NoIntrinsicSizeView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        panel.contentView = container

        // Wide range — fonts scale with window dimensions via SwiftUI's
        // GeometryReader + timerFontSize environment, so the user can drag any
        // direction from compact (text ~16pt) to massive (text ~260pt). Min
        // is sized so both timers + chrome fit at a readable font; max is 400%
        // of v0.3's intended cap. Aspect ratio locked at 8:7 (matches the
        // natural content shape at default sizing) so the user drags one
        // dimension and the other follows proportionally.
        let minSize = NSSize(width: 200, height: 180)
        let maxSize = NSSize(width: 1440, height: 1280)
        panel.minSize = minSize
        panel.maxSize = maxSize
        panel.contentMinSize = minSize
        panel.contentMaxSize = maxSize
        panel.contentAspectRatio = NSSize(width: 8, height: 7)
        panel.aspectRatio = NSSize(width: 8, height: 7)

        // Companion lock-corner window — small always-clickable panel
        // positioned at the main panel's top-left. When the main panel is in
        // click-through mode (isLocked = true), this window is still
        // interactive so the user can tap to unlock. Synced to main panel's
        // position via windowDidMove / windowDidResize.
        installLockWindow(over: panel)

        panel.delegate = self
        panel.orderFrontRegardless()

        self.window = panel
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowDidMove(_ notification: Notification) {
        Task { @MainActor in
            saveFrame()
            positionLockWindow()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            saveFrame()
            positionLockWindow()
        }
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

    // MARK: - Lock-corner companion window (Plan A from v0.3.1 design)

    private func installLockWindow(over main: NSPanel) {
        let size = NSSize(width: 30, height: 30)
        let lock = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        lock.isOpaque = false
        lock.backgroundColor = .clear
        lock.hasShadow = false
        lock.level = NSWindow.Level(rawValue: main.level.rawValue + 1)
        lock.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        lock.isMovableByWindowBackground = false
        lock.hidesOnDeactivate = false
        lock.ignoresMouseEvents = false  // ALWAYS clickable, even when main is locked

        let hosting = NSHostingView(rootView: LockCornerView(controller: self))
        lock.contentView = hosting
        lock.orderFrontRegardless()

        self.lockWindow = lock
        positionLockWindow()
    }

    private func positionLockWindow() {
        guard let main = window, let lock = lockWindow else { return }
        let mainFrame = main.frame
        let lockSize = lock.frame.size
        // Top-left of main window, with 6pt inset to match the visible content
        // padding (.padding(6) outside the rounded background in OverlayView).
        let origin = NSPoint(
            x: mainFrame.origin.x + 6,
            y: mainFrame.origin.y + mainFrame.size.height - lockSize.height - 6
        )
        lock.setFrameOrigin(origin)
    }

    private func saveSettings() {
        var dict = UserDefaults.standard.dictionary(forKey: settingsKey) ?? [:]
        dict["alpha"] = alpha
        dict["isLocked"] = isLocked
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }
}

// MARK: - LockCornerView

/// SwiftUI view rendered in the lock-corner companion NSPanel. Single button
/// that toggles the main overlay's locked state. Lives in a separate window
/// (always clickable) so the user can unlock even when the main overlay is
/// in click-through mode.
private struct LockCornerView: View {
    @ObservedObject var controller: OverlayController

    var body: some View {
        Button {
            controller.toggleLockFromCorner()
        } label: {
            Image(systemName: controller.isLocked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary.opacity(controller.isLocked ? 0.55 : 0.75))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(controller.isLocked
              ? "Locked — tap to unlock (clicks pass through to apps below the overlay)"
              : "Tap to lock — overlay becomes click-through")
    }
}

// MARK: - NoIntrinsicSizeView

/// A container NSView that explicitly returns noIntrinsicMetric, preventing
/// a child NSHostingView's SwiftUI-derived intrinsic size from propagating up
/// to override the parent NSPanel's min/max size limits. Plain NSView allows
/// the propagation (intrinsic size flows through Auto Layout constraints);
/// this subclass blocks it.
private final class NoIntrinsicSizeView: NSView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}
