import AppKit

/// Listens for the hardware Play/Pause media key (the F8-style media button
/// found on Apple keyboards, Bluetooth remotes, and headset controls)
/// system-wide and invokes a handler on press.
///
/// Implemented via NSEvent's `.systemDefined` monitors rather than a
/// CGEventTap — this does NOT require the Accessibility/Input Monitoring
/// permission, which matters since TimeStack is sandboxed and would
/// otherwise need a hard-to-obtain entitlement exception.
///
/// Two monitors are installed because `addGlobalMonitorForEvents` only
/// delivers events bound for OTHER applications; the local monitor covers
/// the case where TimeStack's own menu or overlay window is key.
@MainActor
final class MediaKeyMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onPlayPause: () -> Void

    /// NX_KEYTYPE_PLAY (from IOKit/hidsystem/ev_keymap.h) — the hardware
    /// Play/Pause key's media-key code, carried in the high 16 bits of a
    /// systemDefined NSEvent's `data1`.
    private static let playPauseKeyCode = 16

    init(onPlayPause: @escaping () -> Void) {
        self.onPlayPause = onPlayPause
        start()
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    private func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handle(event)
        }
        // Local monitor so the key still works while TimeStack's own menu or
        // overlay window is key — global monitors only see events bound for
        // OTHER applications.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    /// Decodes a systemDefined NSEvent's packed `data1` field. Media keys use
    /// subtype 8 ("aux control buttons"); the key code sits in bits 16-31,
    /// the pressed/released state in bits 8-15 (0xA = down, 0xB = up), and
    /// the low bit flags key-repeat. Only a fresh (non-repeat) key-down for
    /// the Play/Pause code fires the handler.
    private func handle(_ event: NSEvent) {
        guard event.subtype.rawValue == 8 else { return }

        let keyCode = (event.data1 & 0xFFFF0000) >> 16
        guard keyCode == Self.playPauseKeyCode else { return }

        let keyFlags = event.data1 & 0x0000FFFF
        let keyIsDown = ((keyFlags & 0xFF00) >> 8) == 0xA
        let isRepeat = (keyFlags & 0x1) != 0
        guard keyIsDown, !isRepeat else { return }

        onPlayPause()
    }
}
