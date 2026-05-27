# TimeStack Setup

This repo ships with both a canonical `project.yml` spec (XcodeGen) and a generated `TimeStack.xcodeproj`. Either works.

## Fast path — just open and run

```bash
open TimeStack.xcodeproj
```

Then ⌘R in Xcode. That's it.

The `TimeStack.xcodeproj` bundle is checked in and ready to build. Minimum: Xcode 16+, macOS 13.0+. App Sandbox is enabled; v1.1 adds the `com.apple.security.files.user-selected.read-only` entitlement for the Custom… sound option (lets the user pick their own audio file via the standard Open dialog).

## Reproducible path — regenerate the project from `project.yml`

If you've edited `project.yml` (or want to verify the `.xcodeproj` matches the spec), regenerate with:

```bash
brew install xcodegen   # one-time
xcodegen generate
```

This rewrites `TimeStack.xcodeproj` from `project.yml`. The spec is the canonical source of truth for project settings (bundle ID, target settings, sandbox, INFOPLIST keys, etc.); the `.xcodeproj` is treated as a regenerable artifact and committed for clone-and-run convenience.

For the family-wide rationale on XcodeGen adoption, see KaizenUBA `DECISIONS.md` D-026.

## Distribution

- **Local dev:** "Sign to Run Locally" or your personal team. App runs in the sandbox; nothing additional needed.
- **Mac App Store:** Apple Developer Program membership required ($99/year). Team in `project.yml` is set to `X22WKZG6P4` (Michael Wild); contributors should override locally via Xcode signing UI.
- **Notarized GitHub Release:** Developer ID Application certificate + notarization. Follows the same flow as ClipStack's v1.0 release (see KaizenUBA `OPERATIONS.md` runbook 2026-05-21 for Xcode 16 ITMS-prevention checklist — already baked into `project.yml`).

## If something goes wrong

- **Floating panel doesn't appear:** off-screen saved frame protection (v0.2+) should center it on main screen. If you're on v0.1 or older and it doesn't appear, delete defaults with: `defaults delete com.planbecreative.TimeStack` and relaunch.
- **Panel doesn't stay above Minecraft:** v0.1+ supports Minecraft with the Fullscreen toggle **OFF** (Options → Video Settings → Fullscreen). Fullscreen-Spaces support is roadmap.
- **Click-through doesn't work after locking (v0.4+):** check the lock-corner panel in the overlay's top-left — it's a small always-clickable companion window that shows the closed-padlock state when locked. The main overlay is fully click-through when locked; the lock corner stays clickable so you can tap it again to unlock without leaving the overlay. (v0.3 had a different one-way lock UI; v0.4 replaced it with this two-window architecture per `DECISIONS.md` D-029.)
- **Build fails on `@Published` / `ObservableObject` errors:** Xcode 16's stricter module visibility (`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`) requires explicit `import Combine` alongside `import SwiftUI` in files that conform to `ObservableObject`. This should already be done in current source.
