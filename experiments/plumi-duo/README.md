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

## 18 Nov 2026: runtime crash and hardening revision (v4)

The user's iOS 27.2.1 crash report shows `SIGABRT` in `-[PlumiDuoLayoutController refresh]` when UIKit calls `-[_UITraitOverrides _valueForNSIntegerTraitToken:]`. The prior shim read `overrides.horizontalSizeClass` **before defining an override**. Apple documents that reading an unset override raises an exception. This is a confirmed runtime error rather than a signing/loading failure: the report includes our dylib in `usedImages`.

Fixes implemented in `PlumiDuoLayout.m`:
- Never read an unset `UITraitOverrides.horizontalSizeClass` value.
- Detect existing per-scene trait overrides with `containsTrait:`, and remove only those installed by our shim.
- Catch Objective-C exceptions, disable the shim, and attempt safe rollback.
- Correct notification selectors to accept the notification parameter and use a weak timer capture.
- Guard app bundle ID, iPhone idiom, iOS 27.2.x, active/foreground window scenes, and landscape orientation.
- Add a preferences kill-switch, `PlumiDuoLayoutDisabled` (read on launch).

The macOS Intel build passed and compiled an arm64 dylib. A locally built unsigned IPA using the user's original Plumi 1.2.13 retains all 86 nested signing entries, omits only two obsolete main-app signing entries, modifies only the executable and adds one dylib. Archive CRC validation succeeded. The user's IPA is **not** committed to GitHub.

**Important:** The fix is not proven on-device. A successfully compiled dylib and structurally valid IPA do not establish that the SwiftUI overlap has been fixed or that every runtime path is crash-free. A new signed-on-device test is still required.
