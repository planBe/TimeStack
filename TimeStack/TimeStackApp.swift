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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = self.engine
        let overlay = self.overlay
        overlay.showOverlay {
            OverlayView()
                .environmentObject(engine)
                .environmentObject(overlay)
        }
    }
}
