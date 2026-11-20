import Combine
import SwiftUI

@main
struct TimeStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("TimeStack", systemImage: "stopwatch") {
            MenuBarView()
                .environmentObject(appDelegate.engine)
                .environmentObject(appDelegate.overlay)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let engine = TimerEngine()
    let overlay = OverlayController()
    private var mediaKeyMonitor: MediaKeyMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = self.engine
        let overlay = self.overlay
        overlay.showOverlay {
            OverlayView()
                .environmentObject(engine)
                .environmentObject(overlay)
        }

        // Media keys: Play/Pause toggles the countdown (mirrors the menu's
        // Start/Pause button); the "<<" back-track key adds 10s to it.
        mediaKeyMonitor = MediaKeyMonitor(
            onPlayPause: { [weak engine] in
                guard let engine else { return }
                if engine.countdownRunning {
                    engine.stopCountdown()
                } else {
                    engine.startCountdown()
                }
            },
            onPrevious: { [weak engine] in
                engine?.addCountdownTime(10)
            }
        )
    }
}
