# TimeStack

Free, always-on-top transparent overlay timers for macOS. A stacked **countdown** and **stopwatch** that float above whatever app you're focused on — speedruns, focus sessions, time-boxed builds.

## Status

**v1.0 submitted to the Mac App Store** (2026-05-25, awaiting Apple review). **v1.1 in development** — polish pass adding a bundled Alarm + Siren sound, custom user-sound picker, configurable play count, opt-in delay-start audio tick, and gentle UI scaling at small window sizes.

## Features

- ⏱ Stacked **countdown** + **stopwatch** running simultaneously — show either or both
- 🎯 Configurable countdown target (default 20:00); click-to-edit the numbers in the overlay when stopped
- 🪟 Always-on-top transparent overlay, works over any windowed app
- 🔒 Click-through when locked; an always-clickable lock corner means you can lock or unlock without leaving the overlay
- 📐 Resizable window with adjustable transparency; text scales with window size
- 🎨 Per-timer text colors (NSColorPanel for true-color picking)
- ⌚ Precision picker — whole seconds, tenths, or hundredths
- 🚦 3-2-1 delay before any Start (0–10s, default 3) — keeps your "get back to the game" hand-eye clean
- 🔔 Opt-in countdown-end sound — bundled **Alarm** (default, gentle bee-doo), **Siren** (Taiwan EAS-style wail), 14 macOS system sounds, or pick your own audio file
- 🔁 Play sound Once / 3× / 5× / 10× — any sound becomes alarm-like by repetition
- 🥁 Opt-in audio tick during the 3-2-1 delay
- 💾 Window position/size, target time, colors, sound choice — all persist across launches
- 🍎 Menu bar control (no dock icon)
- 🆓 Free and open-source forever (MIT licensed)
- 🪶 Lean: no runtime dependencies, pure SwiftUI + AppKit

## Requirements

- macOS 13 Ventura or later
- Xcode 16 or later + [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to build from source

## Building from source

The Xcode project is generated from `project.yml` via XcodeGen. From the repo root:

```bash
xcodegen generate
open TimeStack.xcodeproj
```

Then ⌘R to build and run.

## How it works

The overlay is a borderless `NSPanel` at `.statusBar` level (always on top) hosting a SwiftUI view via `NSHostingView`. When locked, `ignoresMouseEvents = true` makes the window click-through. A separate small companion `NSPanel` at the top-left stays clickable regardless, so you can lock or unlock without leaving the overlay — no global hotkey needed (TimeStack stays sandbox-clean by avoiding the Accessibility-permission flow that global hotkeys require on Mac).

Font sizes scale with the window via a SwiftUI `GeometryReader` + custom `Environment` value (`timerFontSize`) — at small windows the timer text floors at 28pt for legibility; at large windows it grows to fill the available space. The card aspect ratio locks dynamically to 8:5 (both timers visible), 8:3 (one timer), or 8:3 (neither — empty state).

Sound playback uses `NSSound` with a delegate-replay model: when you pick "Play 3×", the engine sets `NSSound.delegate` to a `SoundReplayDelegate` that re-calls `play()` after each `sound:didFinishPlaying:` callback until the count is exhausted. Custom user-picked audio files are persisted via Security-Scoped Bookmarks (the sandbox-permitted mechanism for re-accessing user-chosen files across launches).

Settings persist in `UserDefaults` under `TimeStack.settings.v2`. Multi-monitor robust — if a saved window frame is off-screen at launch (monitor unplugged), TimeStack falls back to centering on the main screen.

## Roadmap

- [x] v0.1 — overlay + countdown/stopwatch + click-through lock
- [x] v0.2 — user-customizable colors, precision picker, opt-in countdown-end sound, click-to-edit countdown numbers
- [x] v0.3 — 3-2-1 delay-start
- [x] v0.4 — NSColorPanel-based color UI, font scaling, two-window lock architecture, branded menu header
- [x] v1.0 — submitted to Mac App Store 2026-05-25
- [x] v1.1 — AccentColor asset, gentle header scaling at small windows, opt-in audio tick during delay, custom user-sound picker (Security-Scoped Bookmarks), bundled Alarm + Siren sounds, play-N-times count semantic
- [ ] v1.2 — TBD; candidates include in-app Credits surface, optional custom-sound trimming, additional bundled alarm options

## Privacy

TimeStack collects no data. Everything runs on your Mac; nothing is sent anywhere. See [PRIVACY.md](PRIVACY.md) for the full policy.

## License

MIT. See [LICENSE](LICENSE).

## Credits

- **Alarm** (bundled default sound) — generated programmatically; see [`gen_alarm.py`](gen_alarm.py).
- **Siren** (bundled alternate sound, Taiwan EAS-style wail) — by [jeremayjimenez](https://pixabay.com/users/jeremayjimenez-28887262/) on Pixabay, used under the [Pixabay Content License](https://pixabay.com/service/license-summary/).

## Contributing

Issues and PRs welcome. The codebase is intentionally compact — around 1800 lines of Swift across eight files — so it should be easy to dive in.

## About

Part of the **Stack** family of free, open-source macOS utilities. See also:

- [ClipStack](https://github.com/planBe/ClipStack) — menu bar clipboard history

Made by Michael Wild – plan Be creative.
