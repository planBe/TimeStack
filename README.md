# TimeStack

Free, always-on-top transparent overlay timers for macOS. A stacked **countdown** and **stopwatch** that float above whatever app you're focused on — speedruns, focus sessions, time-boxed builds.

## Status

🚧 **v0.1 — early development.** Spec locked; build in progress.

## Features (v0.1)

- ⏱ Stacked **countdown** + **stopwatch** running simultaneously — show either or both
- 🪟 Always-on-top transparent overlay, works over any windowed app
- 🖱 Click-through when locked; drag to position when unlocked
- 📐 Resizable window, adjustable transparency
- 💾 Window position, target time, opacity, lock state — all persist across launches
- 🍎 Menu bar control (no dock icon)
- 🆓 Free and open-source forever (MIT licensed)
- 🪶 Lean: no dependencies, pure SwiftUI + AppKit

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (to build from source)

## Roadmap (post-v0.1)

- Sound on countdown-zero (optional)
- Multi-monitor — show on the screen where the trigger came from
- Fullscreen-app support (Spaces handling; v0.1 supports windowed apps only)
- Mac App Store distribution
- Notarized release builds via GitHub Releases and Homebrew Cask

## License

MIT. See [LICENSE](LICENSE).

## About

Part of the **Stack** family of free, open-source macOS utilities. See also:

- [ClipStack](https://github.com/planBe/ClipStack) — menu bar clipboard history

Made by Michael Wild – plan Be creative.
