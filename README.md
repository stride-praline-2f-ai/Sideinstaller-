# Install on iPad

A personal, non-commercial installer for sending custom IPAs from an iPhone to a paired iPad. It remembers one iPad, can refresh the apps it signed, and can request Increased Memory Limit when Apple grants it to the signing profile.

Based on [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) at v2.0.1 (`50b2a0dea22d43659e2630e01daa9097145874cb`). The original [license](LICENSE.md) is included. This repository publishes the [source changes](install-on-ipad.patch) and the build workflow for this derivative.

## Build

Open **Actions → Build Install on iPad**. The workflow fetches the pinned upstream revision, applies the source patch, and builds an unsigned IPA with Xcode 27.2 or newer. Download **Install-on-iPad** from the run artifacts and extract `Install-on-iPad.ipa`. Sign the IPA for the iPhone with Signulous. Use the same signing Apple Account on subsequent iPad app refreshes.

For local building and device setup, see `BUILD-INSTALL-ON-IPAD.md` in the patched source tree.

## November 20, 2026: Apple GSA 503 compatibility build (v1.1.2)

The build workflow now applies [auth-503-hotfix.patch](auth-503-hotfix.patch) after the dedicated iPad installer patch. The hotfix changes the Rust GrandSlam macOS-ADI client identity and the two-factor Mac fallback from the `<macOS;...>` spelling to a `<Mac OS X;27.2;26B118>` client-info profile reported to work with Apple's GSA edge on November 20. This is a **provisional compatibility workaround**, not proof that Apple sign-in has been restored on every account or anisette server. The original source is pinned and the hotfix is separate so it can be removed cleanly when upstream addresses the issue.

Use **Actions → Build Install on iPad** and download the `Install-on-iPad` artifact from a **successful** v1.1.2 run. Sign it with the same signing certificate and bundle identifier as the app already installed on the iPhone, and update **in place** to preserve remembered pairing and locally saved refresh archives. Do not uninstall the existing app merely to try this authentication fix. Do not share full sign-in logs, tokens, pairing files or credentials publicly.

## v1.1.3: Certificate management in the dedicated iPad installer

The Install on iPad screen now exposes **Manage signing certificates**. It opens SideInstaller's existing Certificates tool, using the Apple Account saved for the installer, and supports loading the account's certificate list, carefully selecting a certificate to revoke, exporting a certificate this installer has the private key for, and importing SideStore's certificate where supported. Revocation always has a destructive confirmation; nothing is automatically revoked after error **7460**.

**Suggested flow for error 7460:** first check whether you can reuse the existing certificate by importing it from SideStore. If that isn't possible, open Manage signing certificates, load the list, identify the certificate and consider which other apps use it. Revoke it only if you accept that apps signed with that certificate, including on other devices, may stop launching. Close the certificate tool and press **Install on iPad** again. The normal installation pipeline will request a new certificate after revocation. It does not issue one as a side effect of opening the tool. Your saved iPad pairing is not changed.

The new screen reuses the upstream Rust `si_cert_signin`, `si_cert_list` and `si_cert_revoke` functions, rather than implementing certificate revocation independently. It also shows authentication and portal errors inline in the dedicated build, whose root otherwise does not display the standard SideInstaller certificate popups. Source changes are in [cert-management-ipad.patch](cert-management-ipad.patch).

## v1.1.4: Persistent developer sessions and safer -22410 handling

The dedicated **Install on iPad** screen now includes **Apple sign-in settings**, which opens the existing SideInstaller settings (including **Anisette Server**). For an Apple `-22410` rejection at GrandSlam's initial login, the app stops rather than trying the same Apple account against all seven servers. Choose one Mac-ADI anisette server manually with Auto disabled if investigating the error; a different server cannot guarantee that Apple accepts the account/device identity.

For **Apple Accounts saved on this iPhone**, Side by Side now passes `remember_session=1` to `si_apple_signin` and uses its persistent `PrivateStore.isideload` storage. This activates the Rust FFI's existing token reuse across app launches and avoids unnecessary new GrandSlam logins while Apple still accepts the token. **Other people's accounts** continue to pass `remember_session=0` with a temporary directory, and no sessions or credentials are saved to the owner's persistent store.

**Important:** This improves persistence and error handling, but it does not bypass Apple's current `-22410` server-side rejection if the user has no previously saved valid token. Do not revoke signing certificates to fix an initial-login error; that would invalidate other installed apps and wouldn't help initial GrandSlam authentication.

Source: [apple-session-reuse.patch](apple-session-reuse.patch).
