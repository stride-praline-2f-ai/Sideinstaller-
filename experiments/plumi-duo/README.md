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

## 18 Nov 2026: v4 device test FAILED: do not distribute as fix

The user tested v4 on iPhone Duo and shared two screenshots: the new build's subject-onboarding screen and the original version's Chemistry dashboard. Because these are **different screens**, the screenshots cannot establish a strict within-screen comparison. The new onboarding screen appears awkwardly laid out and clipped at the bottom, and the user reports it is worse overall. This is sufficient reason to discontinue the global compact horizontal-size-class experiment.

**Root design problem:** UIWindowScene trait overrides propagate through every descendant in that scene. Forcing compact width globally in landscape is a blunt change; it does not solve per-view width, safe-area and clipping bugs reliably, and can cause unexpected SwiftUI reflows.

- v4 is a **failed experiment**, not a supported compatibility patch.
- Prefer uninstalling/replacing it with the known-working original Plumi IPA.
- On this research branch, the shim now defaults to **no changes**; opting into the old global experiment requires `PlumiDuoLayoutExperimentalOptIn = YES` in app preferences. This opt-in is for controlled development only, not users.
- Do not publish further layout IPAs without same-screen comparison and a narrower patch backed by actual observations.
- Further work should target Plumi's app-defined pane widths or safe-area/insets at the affected screen, ideally with app source or an isolated view implementation. A generic iPad identity or size-class spoof is not a confirmed solution.

## v5: status bar only (conservative on-device test)

User requested hiding the iOS status overlay (clock, Wi-Fi, battery) visible over Plumi navigation on the iPhone Duo. The v4 global compact-size-class shim was unsuccessful and is **not** included. The v5 IPA is built from the user's previously working **original** Plumi 1.2.13 build 40 IPA, not from any patched variant.

Changes:
- Set `UIStatusBarHidden = YES` and `UIViewControllerBasedStatusBarAppearance = NO` in Plumi's main `Info.plist`.
- Preserve `UIDeviceFamily=[1,2]`, SDK metadata, orientation support, scene lifecycle, all assets, original executable and 86 embedded code-signature entries.
- Remove only two invalidated **main app** signature entries for complete re-signing by the user's installer.
- No injected dylib, no UIWindowScene trait overrides, no MobileGestalt or global device changes.

Verified in local preflight: ZIP CRC passes, executable byte-identical to original, no other file-content changes, three synthetic build tests pass. Expected unsigned IPA SHA-256: `bf2836e671cf3e5420d017a9ae4358a7ddbe1557738a9f255a37767eef700d83`.

**Not verified:** The actual iOS status-bar visibility or Chemistry dashboard clipping after Signulous signing, and preservation of user app data on reinstall. Apple developer forums document unrelated cases where status-bar visibility changes altered navigation layout on some iOS versions; be prepared to revert if v5 performs worse.

Do not label v5 a full Duo layout fix. Further work on the right-hand pane clipping must target actual Plumi SwiftUI view geometry, preferably with app source or a same-screen comparison.

## iPad mini layout policy for iPhone Duo (source-level reference)

The user requested preserving the iPad mini experience wherever it fits, while fixing the Chemistry dashboard's off-screen right pane. Static analysis of Plumi 1.2.13 found compiled app-defined pane layout tests referring to a **679-point iPad mini destination** and **469-point compact Settings destination**. Apple notes that iPhone Duo can report a regular horizontal size class without having iPad-sized space.

A *source-level* candidate is now included in `source-reference/`:
- `PlumiPanePolicy.swift`: choose split columns only when available safe-area-aware width fits a 460-point main pane, 300-point sidebar and 20-point spacing; otherwise stack.
- `PlumiAdaptiveColumns.swift`: generic SwiftUI view using `GeometryReader` and `safeAreaPadding`, intended only for the Chemistry/dashboard pane, never a global size-class override.
- `PlumiPanePolicyTests.swift`: 10 width-policy tests.
- `.github/workflows/plumi-adaptive-columns.yml`: macOS Xcode iOS type-check and native policy tests; **passed in GitHub Actions run #44405578269**.

The thresholds are **provisional** until the actual dashboard's SwiftUI content sizing is measured on device. No Plumi source code is accessible in the received compiled IPA, so **the reference view is not integrated into an installable Plumi IPA**. Do not distribute as a working fix or merge into the existing app. The last installable candidate remains v5 (status-bar-only); its on-device results are still unverified.
