import MediaPlayer

/// Claims the system's "Now Playing" media-key routing so TimeStack
/// receives the hardware Play/Pause and "⏮ / <<" back-track keys, even
/// while backgrounded.
///
/// Raw `NSEvent.systemDefined` monitoring (the original approach) doesn't
/// reliably reach apps that aren't frontmost or registered as the active
/// "Now Playing" app — modern macOS routes hardware media keys through
/// `MPRemoteCommandCenter` / `MPNowPlayingInfoCenter`, not a system-wide
/// NSEvent broadcast. Claiming a perpetual "playing" Now Playing entry
/// (even though TimeStack plays no actual media) is what makes macOS treat
/// it as eligible to receive those commands. No special entitlement is
/// needed — just linking the MediaPlayer framework, which Xcode does
/// automatically from the `import`.
@MainActor
final class MediaKeyMonitor {
    private let commandCenter = MPRemoteCommandCenter.shared()

    init(onPlayPause: @escaping () -> Void, onPrevious: @escaping () -> Void) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "TimeStack",
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing

        // Command handlers can fire on a background queue (MediaPlayer's
        // internal dispatch), so hop back to the main actor before touching
        // TimerEngine — none of its mutating APIs are safe to call off it.
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in onPlayPause() }
            return .success
        }
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in onPlayPause() }
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in onPlayPause() }
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in onPrevious() }
            return .success
        }
    }
}
