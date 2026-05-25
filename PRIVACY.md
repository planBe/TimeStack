# TimeStack Privacy Policy

**Last updated:** 2026-05-25

## Summary

**TimeStack collects no data.** It runs entirely on your Mac. Nothing is sent to any server. No analytics, no telemetry, no third parties.

## What TimeStack does

TimeStack is a menu bar timer app that displays a floating overlay with a countdown and a stopwatch. Your settings (countdown target time, panel position and size, lock state, transparency, text colors, precision, sound choice, delay-start duration, per-timer visibility) are stored locally on your Mac in your user account's preferences (`UserDefaults`). They never leave your device.

## Data TimeStack does NOT collect

- Personal information (name, email, address, phone)
- Device identifiers (IDFA, UUID, hardware serial)
- Location
- Health, financial, browsing, or search data
- Crash reports or diagnostics
- Anything sent over the network — TimeStack makes no network calls

## Third parties

TimeStack uses no third-party SDKs, no analytics services, no advertising networks, no crash reporters. The full source code is published at https://github.com/planBe/TimeStack so you can verify this yourself.

## App Sandbox

TimeStack runs inside Apple's App Sandbox with no network entitlements and no file-system entitlements beyond what's required for the system to function. It can only access its own private container.

When you choose a notification sound, TimeStack plays one of the 14 macOS-bundled system sounds (`/System/Library/Sounds/`) via the standard `NSSound` API. No custom audio files are bundled or downloaded.

## Children's privacy

TimeStack is not directed at children under 13. Because TimeStack collects no data at all, no child-specific protections beyond those above are necessary.

## Changes to this policy

If TimeStack ever changes its data practices, this file will be updated and the "Last updated" date above will change. Past versions of this policy are available in the git history at https://github.com/planBe/TimeStack/commits/main/PRIVACY.md.

## Contact

Questions about this policy or about TimeStack itself: open an issue at https://github.com/planBe/TimeStack/issues or email **michael@planbecreative.com**.

---

Made by Michael Wild – plan Be creative.
