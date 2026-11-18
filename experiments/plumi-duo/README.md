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

## 18 November 2026: compiled binary forensics and safe geometry diagnostic

Inspected the user's original Plumi 1.2.13 executable, not just its Info.plist. Swift nominal-type metadata confirms `PaneLayout`, `SubjectOverviewLayout`, `SubjectOverviewPage`, `SettingsLayout`, `AppShell` and `ShellChrome`. Embedded test names refer to iPad mini portrait, narrow iPad configurations, and preventing two-column overflow. These names do **not** identify the specific ARM64 method controlling the Duo's Chemistry dashboard. The IPA has no editable SwiftUI layout source/resource. Blind numeric patches are therefore not validated.

New code: `PlumiDuoProbe.m` and `build-plumi-probe.yml`. GitHub Actions run [#44409944327](https://github.com/stride-praline-2f-ai/Sideinstaller-/actions/runs/44409944327) **passed** on macOS-26-intel; it compiles a read-only arm64 geometry probe. The probe is injected into the original user-provided IPA in the local container, with only its dylib load command and the status-bar plist keys modified. 86 embedded signatures are preserved and only stale root signing metadata is omitted. The original IPA is not published to this repository.

The resulting **unsigned geometry diagnostic IPA** passed ZIP integrity and package-difference checks, SHA-256 `1a2f78707942ff3cea6e6e9e9a006316fda0b9679470a5f221a0d5d484552fb5`. It is **not a finished iPad-mini layout fix**. After Signulous signing, navigate to the clipped Chemistry dashboard, then use a **two-finger triple tap** to export `PlumiDuoGeometry.txt` from the system share sheet. The report includes window bounds, safe area, trait class and UIKit view frames only, not questions, user IDs or account data. Same-screen portrait and landscape screenshots are needed for comparison.

No trait modification, device spoofing, SDK editing, system-level settings change or swizzling occurs in the diagnostic dylib. If installation or launch fails, revert to the untouched original IPA.

## Targeted-width investigation from on-device report

The user captured the Chemistry/dashboard in landscape on iOS 27.2.1:
- UIWindow / scene: **951 × 669 pt** (safe-area top 0, bottom 34)
- Horizontal size class **regular (2)**; no need to spoof tablet identity
- Main SwiftUI HostingScrollView PlatformContainer at (0,211), **1,024.7 × 458 pt**
- Its content width is 1,024.7 pt, and it extends **73.7 pt** beyond the 951-pt window
- Upper navigation PlatformContainer starts x=64.7 with width 895.3, exceeding the window by 9.0 pt

This supports a concrete **oversized SwiftUI container** diagnosis. It does not prove every private SwiftUI child view stays within 1,024.7 pt, and it does not prove the iPad mini layout can be directly enabled.

### Plumi v7: per-view fit, user-controlled and reversible

`PlumiDuoViewportLab.m` is an iPhone-only, `dev.plumi.app`-scoped experimental dylib, compiled on GitHub macOS (Actions run **44412336844**). It installs a two-finger **triple-tap** control. The default launch modifies **no layouts**. The user can apply either:
- **Fit container to screen**, approximately 92.8% on the captured dashboard
- **Tighter fit (85%)** if the right panel still extends beyond the edge
- **Restore original layout** without reinstalling

The shim targets only an oversized SwiftUI `HostingScrollView.PlatformContainer` below the dashboard heading, and applies a UIKit view transform (not a horizontal size-class or MobileGestalt override). It attempts automatic restore on rotation. This changes visual scale and may reduce text size; it is **not** native iPad mini SwiftUI reflow. A UI framework can reset the transform on later layout passes, so neither correctness nor durable fit is guaranteed without on-device testing.

An unsigned IPA has been produced locally using the user's original Plumi 1.2.13 build 40, retaining status-bar hidden Info.plist flags. Checks verified:
- ZIP CRC passes
- exactly two existing files changed (main Mach-O load command, main Info.plist)
- exactly one dylib added, two obsolete root-signature entries removed
- all **86** nested signing entries preserved; no layouts, assets, app data or system files otherwise changed
- output SHA-256 `909db3e170353e7df0cb99b28be1adf6716cc9d201cf81652c14a591abad9f95`

**Still experimental:** Requires signing all injected code, launch testing on Duo, and observing whether the dashboard can be fitted without clipping or gesture issues. Revert with the original known-working IPA if anything fails.

## v8 (18 Nov 2026): fix false 'No oversized dashboard' result

The user installed v7 and reported the message **"No oversized dashboard container is visible"** while the Chemistry dashboard was visibly overflowing in landscape. This is the v7 heuristic failing, **not proof that Plumi stopped overflowing**.

v8 changes in `PlumiDuoViewportLab.m`:
- Allow the action sheet to finish dismissing before measuring the underlying UI (0.55-second delay after the user chooses Fit).
- Broaden UIKit/SwiftUI wrapper detection: accept `HostingScrollView` and `PlatformContainer` wrappers with measured overflow; recurse deeper and avoid requiring both strings in the same class name.
- Add **Export screen geometry report** to the two-finger triple-tap menu. When the fit still cannot locate a view, export the report for that same screen instead of reinstalling another diagnostic IPA.
- Keep **Restore original layout** and the 85% user-selected fit. No automatic scaling, system-wide size-class overrides or iPad device spoofing.
- Preserve the status-bar suppression from v5 and the original app/embedded framework resources.

GitHub Actions macOS build **44413917646** compiled successfully. The unsigned v8 IPA was packaged locally from original Plumi 1.2.13 build 40. ZIP CRC and file-difference checks passed; all 86 nested signing entries were retained. Output SHA-256: `2dc8789b9625295e9063d7fed031d10bcfc256c54e42b0cd1b0969d535d08ce3`.

**Still unverified:** Whether v8 now matches the actual Chemistry container or reveals the right panel; whether the view transform persists through SwiftUI re-layout. Do not market as an iPad mini native layout implementation.

## v9 (18 November 2026): diagnosis refined from latest user report

The user supplied an on-device screenshot and a new, same-screen v8 geometry report (window **951 × 669 pt**):

- Right sidebar: `SwiftUI.HostingScrollView` at **x=646.7, y=260.7, width=304.3, height=246.1 pt**.
- Its **contentSize.width=376.0 pt**, overflowing its viewport by **71.7 pt** (scale-to-fit ratio **304.3/376.0 = 0.8093**).
- The nested `PlatformGroupContainer` itself is **304.3 pt** wide and **474.3 pt** high, so a search for *view frame wider than the entire screen* cannot match this problem.
- Separate upper navigation scroll view at **x=77.7, y=77, width=895.3 pt** extends **22.0 pt** beyond the window (but reports contentSize.width=213.7; this is a separate issue).
- Left-hand scroll host x=44 y=638.7 width566.7 contentWidth566.7 does not have horizontal content overflow.

**New artifact: `PlumiDuoSidebarFit.m`** compiled successfully on macOS in [Actions run #44415214541](https://github.com/stride-praline-2f-ai/Sideinstaller-/actions/runs/44415214541).

v9 detects a right-side UIScrollView from actual `contentSize.width > bounds.width + 20`, rather than misidentifying the whole SwiftUI host. Only after a two-finger triple-tap does the user choose to:
1. Visually scale its inner `PlatformGroupContainer` to approximately **80.9%**, with a reversible transform.
2. Enable horizontal scrolling within that right panel instead, without shrinking its text.
3. Restore the original state.

No automatic sizing changes, no iPad-device spoofing, no system-wide trait overrides. The main Plumi SwiftUI executable remains functionally unchanged apart from the added library load command. Status-bar-hidden Info.plist flags are retained.

Unsigned v9 IPA SHA-256: `2349eb342ad609be565f7eefdfac2a212fb76c4118899ad43e26b6cd1d66e10c`. Local archive/difference checks pass; 86 nested signatures preserved, two obsolete main-app signature entries omitted for re-signing. Output is **not tested on a Duo** and **not a native iPad mini reflow**. The upper navigation 22-point overflow is **not fixed in v9**.

The original Plumi IPA remains the known working fallback.

## v11 (18 November 2026): make actions clearly functional after v9 modal failure

The user reported that **none of the v9 buttons worked**, including Restore. Screenshot showed two overlapping iOS alerts. The v9 failure had two causes:
1. Detecting the view after presenting an action sheet changed its effective geometry and made the selection fail.
2. Reporting errors with another `UIAlertController` produced a second blocking alert over the first.
3. Restore never had any modification to undo, but still claimed that the original layout was restored.

The latest `PlumiDuoSidebarFit.m` now:
- Measures and retains a **weak reference to the sidebar before opening the menu**, along with its pre-menu content/viewport widths.
- Shows the captured dimensions and current patch state in the menu.
- **Disables Fit and Scroll when no matching target is available**, instead of allowing misleading failure actions.
- **Disables Restore until an adjustment has actually been applied**, then restores original transforms/scroll settings.
- Uses nonmodal, automatically disappearing labels for all results. No nested UIAlertControllers.
- Schedules the action until after the menu closes.
- Leaves Plumi unchanged at launch.

On the prior measured screen, the intended target predicate matches **x=646.7, y=260.7, viewport=304.3, content=376.0 pt**. This is an expected match based on supplied data, not yet a live validation.

GitHub macOS Intel compile passed: [run #44417162417](https://github.com/stride-praline-2f-ai/Sideinstaller-/actions/runs/44417162417).

The resulting **unsigned v11 test IPA** was packaged locally from the known-working original 1.2.13 build 40 (no v9/v10 nesting) with the status-bar-hidden plist setting. Its SHA-256 is `13d1bbf188d519e7308326aa0300a9138daa4b0cce8fc27e3207956d0e843687`. Package CRC and file-difference checks passed; 86 nested signatures remain intact. This does not establish the behaviour on the phone, the desired iPad mini layout, or a signed build. The user must sign and test it on-device; revert to the original if anything fails.

## Native iPad mini style requested: exact Duo geometry policy (18 Nov 2026)

Goal: retain Plumi's iPad-style navigation and **two-column** Chemistry dashboard on the unfolded 951×669-point Duo, avoid original 71.7-point right-pane internal overflow, and retain a single-pane view on narrower folded/portrait sizes.

The updated source-only `PlumiPanePolicy.swift` now uses **376-point sidebar**, **480-point minimum main pane** and **16-point gap**, subtracting **16-point outer margins** each side. At the measured 951-point Duo width, this yields **527-point main pane + 376-point sidebar + 16 gap + 32 margins**. At 744-point iPad mini portrait, it becomes stacked. On 1133-point landscape it is two-column.

This is a precise **source-level** responsive-layout design, not a compiled-Plumi binary patch. The received IPA contains no editable Plumi dashboard source. Do **not** claim it is installed or working on the Duo. Using a global iPad idiom or width-class override was already tested and worsened Plumi; those approaches remain excluded. The original app is intentionally untouched.

## v12 (18 Nov 2026): automatic, Duo-sized partial workaround (not native iPad mini)

User requested an installable fixed IPA with no broken buttons. Since Plumi is currently available to us only as a compiled iPad-oriented IPA, **the desired native iPad-mini layout reflow still cannot be implemented from the source-only reference files**. v12 is an independent app-only attempt to make the known clipping areas usable, without reusing failed size-class overrides.

Changes to `PlumiDuoSidebarFit.m`:
- No more triple-tap menu or blocking alerts. A lightweight 1.25-second timer automatically checks visible Plumi windows.
- Restricted to `dev.plumi.app`, `UIUserInterfaceIdiomPhone`, iOS 27.2.x and an unfolded landscape window approximately 951×669 points.
- For a right-side UIScrollView matching the measured region (x646.7,y260.7,viewport304.3,content376), automatically enable horizontal scrolling/bounce/indicator. This makes extra content potentially reachable **without claiming all 376 points display at once**.
- For the narrow top navigation container, attempt to shift it left by a measured overflow of about 22 points.
- Preserve the old scrolling state and navigation transform for restoration in portrait. A UserDefaults key `PlumiDuoAutoFixDisabled` can disable modifications when set true.
- Do not change the app's SwiftUI view structure, other screens, scene size classes, device identity, or backend/authentication.

GitHub compile: [run 44420648071](https://github.com/stride-praline-2f-ai/Sideinstaller-/actions/runs/44420648071) passed. The unsigned IPA was built **from the original 1.2.13 build 40**, not from v11. SHA-256: `45c2a9c6e6e7aecdc271bcbfdf522143586ba700acde15cd6997be01f53a45f0`. ZIP CRC, binary/Info.plist difference scope, compiled library identity and the 86 preserved nested signatures all passed. The library was tested only for compilation, not on the user's physical Duo. Requires complete Signulous re-signing.

**Do not advertise v12 as a fully fixed native Plumi Duo layout.** The right-hand sidebar should be swipeable if SwiftUI allows UIKit horizontal scrolling, but its content remains wider than its view. A true two-pane 527/376pt redesign needs Plumi's SwiftUI dashboard source or an independently validated equivalent.
