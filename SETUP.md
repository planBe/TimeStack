# Xcode Setup Guide

The Swift / plist files in `TimeStack/` are the entire app. Here's how to wrap them in an Xcode project that builds.

## Step 1: Create a new Xcode project

1. Open Xcode → **File → New → Project…**
2. Choose **macOS → App** → Next
3. Fill in:
   - **Product Name:** `TimeStack`
   - **Team:** Your Apple ID (or "None" for local dev — see "Distribution" below)
   - **Organization Identifier:** `com.planbecreative` (so the bundle ID becomes `com.planbecreative.TimeStack`)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** None
   - **Include Tests:** unchecked (optional)
4. Save it inside this repo at the top level — sibling to `TimeStack/` (the source folder) — so the resulting structure is:
   ```
   TimeStack/                       (repo root)
   ├── LICENSE
   ├── README.md
   ├── SETUP.md
   ├── .gitignore
   ├── TimeStack.xcodeproj          ← created by Xcode in step 1
   └── TimeStack/                   ← source folder (already in repo)
       ├── TimeStackApp.swift
       ├── TimerEngine.swift
       ├── ...
   ```

Xcode generates a default project with `TimeStackApp.swift` and `ContentView.swift` inside its own `TimeStack/` group.

## Step 2: Replace the generated files

1. In Xcode's file navigator, **delete** the default `TimeStackApp.swift` and `ContentView.swift` (choose "Move to Trash"). Xcode also created an `Info.plist` and an entitlements file — leave those for now; you'll either point Xcode at the repo's versions in step 3, or use Xcode's defaults.
2. Drag these files from the repo's `TimeStack/` folder into the `TimeStack` group in Xcode:
   - `TimeStackApp.swift`
   - `TimerEngine.swift`
   - `OverlayController.swift`
   - `OverlayView.swift`
   - `TimerPanel.swift`
   - `MenuBarView.swift`
   - `TimeFormatter.swift`
3. When prompted, leave **"Copy items if needed" unchecked** (the files are already in this repo's `TimeStack/` source folder; you want Xcode to reference them, not duplicate). Make sure the `TimeStack` target is selected.

## Step 3: Configure the target

In the project settings (click the blue project icon at the top of the file navigator):

1. Select the **TimeStack** target → **General** tab:
   - **Minimum Deployments:** macOS **13.0**
   - **App Category:** Utilities (optional)

2. **Info** tab — add these keys to the auto-generated Info.plist (Xcode will reference its own; copy the values from this repo's `Info.plist` if you'd rather match exactly):
   - **Application is agent (UIElement)** = `YES` *(hides the dock icon — critical for a menu bar app)*
   - **Bundle version** = `1`
   - **Bundle version string, short** = `0.1.0`

3. **Signing & Capabilities** tab:
   - For local testing, "Sign to Run Locally" is fine.
   - The default App Sandbox capability is okay — no special entitlements needed.

## Step 4: Build and run

⌘R. You should see:

- A clipboard-icon-style **stopwatch** icon appear in your menu bar.
- A small floating panel with two stacked timer displays (countdown + stopwatch) appear above your other windows. By default both timers show `20:00.0` (countdown) and `00:00.0` (stopwatch).

Click the menu bar icon to open the control surface: start/pause/reset each timer, change the countdown target time, toggle visibility per timer, lock click-through, adjust opacity.

## If something goes wrong

- **No floating panel appears:** check Console.app for "TimeStack" messages. If the panel was created but isn't visible, it may have a saved frame off-screen — delete `TimeStack.overlay.v1` from defaults to reset (in Terminal: `defaults delete <bundle-id>`).
- **Panel doesn't stay above Minecraft:** v0.1 supports Minecraft with the Fullscreen toggle **OFF** (Options → Video Settings → Fullscreen). Fullscreen-Spaces support is on the v0.2+ roadmap.
- **Click-through doesn't work after locking:** sanity check that "Lock (click-through)" toggle in the menu bar is actually on. When locked, you cannot drag the panel — that's intentional. Unlock to reposition.
- **Settings (target, opacity, lock) don't persist across launches:** sandbox UserDefaults issue. Check Console.app for write failures.

## Distribution

- **Local dev:** "Sign to Run Locally" is fine; no Apple Developer Program membership required.
- **Mac App Store:** Apple Developer Program membership required ($99/year). The Sandbox capability is already set; no other entitlements needed for v0.1.
- **Notarized release builds (GitHub Releases):** requires Developer ID Application certificate + Apple's Notarization service. Out of scope for v0.1; on the roadmap.
