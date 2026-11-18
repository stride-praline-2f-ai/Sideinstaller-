# Plumi / iPhone Duo layout investigation

**Status:** diagnosis complete; no runtime layout patch validated. This is an isolated research branch, **not** a modification to the working SideInstaller or DuoSDK app.

## Input inspected
- Provided IPA: `Plumi_1.2.13_Duo_NoExtensions(1).ipa`
- App: `dev.plumi.app`, version 1.2.13, build 40
- IPA SHA-256: `b90084669c69766c756e1f0ad62a48f6daa1d96bf89ce7a52a475e122bf312e5`
- Executable: arm64 Mach-O, SDK 27.2.0, deployment target 17.0.0
- Info.plist: `UIDeviceFamily = [1,2]`, `DTSDKName = iphoneos27.2`, `UIRequiresFullScreen = false`
- No explicit `UIApplicationSceneManifest`, despite the SwiftUI App lifecycle
- SwiftUI, `GeometryReader`, `UITraitCollection` and `userInterfaceIdiom` symbols/strings are present
- Own app symbols/strings mention `PaneLayout`, `SubjectOverviewLayout`, `PaneLayoutTests`, `iPad mini portrait`, and sizing assumptions for a 469-point Settings page
- Mach-O load-command area has 4,984 zeroed bytes before the first executable section; this indicates potential space for an **experimental** dylib load command, not a working patch.

## Comparison with [patriot1889/patch-ipa-duo](https://github.com/patriot1889/patch-ipa-duo)

As of 18 Nov 2026, its generic patch path requires an explicit application scene manifest. Plumi has none. Its version and iPhone-family options are already satisfied by Plumi's metadata. Standard UIKit bar overrides are not a demonstrated fix for app-owned SwiftUI geometry. The upstream adapter format permits app-specific work, but a working scene bridge would have to be independently verified.

The `adapters/dev.plumi.app.json` file intentionally designates Plumi as *inspection only* rather than fabricating a scene delegate or producing a false-successful IPA.

## Assessment

The strongest lead is the app's own pane-width and two-column logic. A system-wide iPad identity spoof risks worsening the layout and is **not** recommended. A future per-app fix would require the exact screen/rotation where the overlap occurs and runtime testing of the affected SwiftUI pane. Code-signing is required for any modified IPA.

## What is included

- `plumi_probe.py`: read-only IPA metadata / Mach-O inspection; does not patch binaries.
- `adapters/dev.plumi.app.json`: explicit inspection-only upstream adapter descriptor.
- No copyrighted Plumi executable, user data, IPA, private provisioning profiles or signing certificates.

**No working Plumi fix is claimed.** Building and distributing an untested binary merely because its metadata changes would not be useful.
