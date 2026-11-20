# Install on iPad

A personal, non-commercial installer for sending custom IPAs from an iPhone to a paired iPad. It remembers one iPad, can refresh the apps it signed, and can request Increased Memory Limit when Apple grants it to the signing profile.

Based on [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) at v2.0.1 (`50b2a0dea22d43659e2630e01daa9097145874cb`). The original [license](LICENSE.md) is included. This repository publishes the [source changes](install-on-ipad.patch) and the build workflow for this derivative.

## Build

Open **Actions → Build Install on iPad**. The workflow fetches the pinned upstream revision, applies the source patch, and builds an unsigned IPA with Xcode 27.2 or newer. Download **Install-on-iPad** from the run artifacts and extract `Install-on-iPad.ipa`. Sign the IPA for the iPhone with Signulous. Use the same signing Apple Account on subsequent iPad app refreshes.

For local building and device setup, see `BUILD-INSTALL-ON-IPAD.md` in the patched source tree.

## November 20, 2026: Apple GSA 503 compatibility build (v1.1.2)

The build workflow now applies [auth-503-hotfix.patch](auth-503-hotfix.patch) after the dedicated iPad installer patch. The hotfix changes the Rust GrandSlam macOS-ADI client identity and the two-factor Mac fallback from the `<macOS;...>` spelling to a `<Mac OS X;27.2;26B118>` client-info profile reported to work with Apple's GSA edge on November 20. This is a **provisional compatibility workaround**, not proof that Apple sign-in has been restored on every account or anisette server. The original source is pinned and the hotfix is separate so it can be removed cleanly when upstream addresses the issue.

Use **Actions → Build Install on iPad** and download the `Install-on-iPad` artifact from a **successful** v1.1.2 run. Sign it with the same signing certificate and bundle identifier as the app already installed on the iPhone, and update **in place** to preserve remembered pairing and locally saved refresh archives. Do not uninstall the existing app merely to try this authentication fix. Do not share full sign-in logs, tokens, pairing files or credentials publicly.
