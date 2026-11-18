# Can worse_query enable Apple Pencil Pro on iPhone Duo?
Research note, 18 November 2026

## Verdict

**No verified software-only route.** The Duo already supports Apple Pencil (USB-C). The public MobileGestalt key `DeviceSupportsApplePencil` (`yhHcB0iH0d1XzPO/CFd3ow`) represents *generic Pencil capability*, not a model allowlist. It is already functionally enabled on Duo for USB-C Pencil. Editing it is not a supported way to enable Pro.

`worse_query` accesses selected MCM app/system containers, including the MobileGestalt cache. It does **not** provide kernel privileges, code execution inside Apple touch drivers, arbitrary `/System` modification, or a new hardware radio. Updating a cache value therefore cannot by itself install or change the Pencil Pro touch/pairing protocol.

## New evidence: Apple's published accessory specifications

Apple's October 2026 Stylus Inking Accessory Design Specification lays out a two-part process for compatible BLE HID styluses:

1. The host sees the expected BLE HID digitizer report descriptor (top-level usage 0x0D / 0x20) and Apple vendor HID usages (0xFF60).
2. The host writes tip and ring stimulation frequencies and the stim-enable command. If required usages are absent, **the host does not activate inking, without showing an error**.

This directly explains why an app can report a stylus as Bluetooth-paired yet not receive tip input.

Apple's iPhone Duo EU third-party accessory programme includes USB-initiated and proximity-initiated BLE pairing, with accessory registration. The programme is aimed at manufacturers of newly compatible styluses, **not retroactive Pencil Pro unlocking**. Its access rules are EU-focused, not a proven UK route.

Pencil Pro officially pairs by attachment to a compatible iPad's magnetic connector. Duo lacks that pairing connector, and no public documentation shows that Pencil Pro can expose the same HID feature/inking protocol or independently enter a compatible pairing mode on Duo.

## Why a third-party Bluetooth app doesn't solve it

Ordinary CoreBluetooth apps cannot force iOS to bind a BLE device to the privileged system Pencil HID driver. A Bluetooth connection, battery widget and digitizer-sensed Pencil-tip event are separate stages. LightBlue successfully pairing first-gen Pencil in third-party testing did not produce tip events.

The two main unresolved questions are:
- Can Pencil Pro establish a *trusted pair and control channel* without the iPad's magnetic connector?
- If so, does Pencil Pro emit tip signals in a frequency/protocol mode the Duo digitizer can recognise?

Neither is answered affirmatively by current public code. Broad device-class spoofing is not a substitute.

## Implemented non-destructive research

`DuoPencilProbe` is a minimal iPhone iOS app. Its own drawing surface classifies UIKit touch events into `.pencil` versus `.direct`, shows force and altitude, and paints Pencil events blue. It does not request Bluetooth privileges, collect pairing keys, modify system files, or invoke `worse_query`.

Suggested comparison:
1. Draw with finger (grey/different touch type).
2. Pair USB-C Pencil normally and draw (blue and `.pencil` expected).
3. Try Pencil Pro. If no `.pencil` event is delivered, there's nothing for ordinary user-space apps to route into Notes or other apps. Absence alone does not distinguish BLE pairing failure from missing HID descriptor or incompatible electrode signalling.

## What might change the verdict?

- Verified evidence of an on-Duo Pencil Pro HID connection with a supported stimulation descriptor, **and** no touch input (a likely driver/allowlist decision).
- A discovered **device-local software switch** controlling supported stylus models that can be read and tested without changing device class, together with a rescue method.
- A documented Pencil Pro pairing and stimulation channel independent of magnetic coupling.

Until then, a purported "Pro unlock IPA" would be invented functionality. Risky MobileGestalt surgery on a primary phone isn't justified.

## What a hardware-assisted design would entail

At least a magnetic Pencil Pro pairing and charging interface plus a firmware bridge mapping its protected/potentially incompatible protocol to a Duo-supported registered BLE HID inking accessory. Merely creating a BLE connection or replacing the Pencil's Bluetooth name is not enough; the physical tip and ring signals must be correct. This is a substantial reverse-engineering hardware project, and may still be impossible without Pencil firmware control.

## Sources

- https://github.com/forcequitOS/worse_query
- https://github.com/kolbicz/WQFiles
- https://github.com/rooootdev/mond/blob/main/mond/helpers/mg.swift
- https://theapplewiki.com/wiki/List_of_MobileGestalt_keys
- https://developer.apple.com/support/stylus-support-for-iphone-duo-in-the-eu
- https://developer.apple.com/download/files/Stylus-Inking-Accessory-Design-Specification.pdf
- https://developer.apple.com/download/files/Stylus-Inking-Hardware-Specification.pdf
- https://developer.apple.com/download/files/Accessory-USB-triggered-Bluetooth-Pairing-Specification.pdf
- https://highlightsapp.net/blog/2026/10/29/iPhone-Duo-Apple-Pencil-Support/
- https://support.apple.com/guide/ipad/pair-and-charge-apple-pencil-pro-ipada6b9b799/27/ipados/27
