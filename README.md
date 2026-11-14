# Install on iPad

A personal, non-commercial installer for sending custom IPAs from an iPhone to a paired iPad. It remembers one iPad, can refresh the apps it signed, and can request Increased Memory Limit when Apple grants it to the signing profile.

Based on [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) at v2.0.1 (`50b2a0dea22d43659e2630e01daa9097145874cb`). The original [license](LICENSE.md) is included. This repository publishes the [source changes](install-on-ipad.patch) and the build workflow for this derivative.

## Build

Open **Actions → Build Install on iPad**. The workflow fetches the pinned upstream revision, applies the source patch, and builds an unsigned IPA with Xcode 27.2 or newer. Download **Install-on-iPad** from the run artifacts and extract `Install-on-iPad.ipa`. Sign the IPA for the iPhone with Signulous. Use the same signing Apple Account on subsequent iPad app refreshes.

For local building and device setup, see `BUILD-INSTALL-ON-IPAD.md` in the patched source tree.
