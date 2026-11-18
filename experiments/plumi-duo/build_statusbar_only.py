#!/usr/bin/env python3
"""Build a Plumi status-bar-only IPA from the original known-good build.

No dylib injection, no SwiftUI trait changes, no scene modification.
The output is unsigned: re-sign it with your normal signer before installing.
"""
import hashlib
import plistlib
import sys
from pathlib import Path
from zipfile import ZipFile

APP = "Payload/Plumi.app/"
PLIST = APP + "Info.plist"
EXE = APP + "Plumi"
STALE_MAIN_SIGNATURE = {APP + "_CodeSignature/", APP + "_CodeSignature/CodeResources"}


def build(original: Path, destination: Path):
    if destination.exists() or original.resolve() == destination.resolve():
        raise ValueError("Output exists or collides with input")
    with ZipFile(original) as src:
        info = plistlib.loads(src.read(PLIST))
        assert (info["CFBundleIdentifier"], info["CFBundleShortVersionString"],
                info["CFBundleVersion"], info["UIDeviceFamily"]) == (
                "dev.plumi.app", "1.2.13", "40", [1, 2])
        updated = dict(info)
        updated.update(UIStatusBarHidden=True,
                       UIViewControllerBasedStatusBarAppearance=False)
        updated_plist = plistlib.dumps(updated, fmt=plistlib.FMT_BINARY)
        with ZipFile(destination, "x", allowZip64=True) as dst:
            for member in src.infolist():
                if member.filename in STALE_MAIN_SIGNATURE:
                    continue
                dst.writestr(member,
                             updated_plist if member.filename == PLIST
                             else src.read(member),
                             compress_type=member.compress_type,
                             compresslevel=6)
    with ZipFile(original) as src, ZipFile(destination) as dst:
        assert dst.testzip() is None
        assert src.read(EXE) == dst.read(EXE)
        assert set(src.namelist()) - set(dst.namelist()) == STALE_MAIN_SIGNATURE
        assert not (set(dst.namelist()) - set(src.namelist()))
        assert all(src.read(n) == dst.read(n)
                   for n in dst.namelist() if n != PLIST)
        report = {
            "changed_files": [PLIST],
            "removed_obsolete_main_signature": sorted(STALE_MAIN_SIGNATURE),
            "preserved_nested_signature_entries": sum(
                "_CodeSignature" in n for n in dst.namelist()),
            "sha256": hashlib.sha256(destination.read_bytes()).hexdigest(),
            "unsigned": True,
            "on_device_layout_result": "UNVERIFIED",
        }
        return report


if __name__ == "__main__":
    import json
    if len(sys.argv) != 3:
        print("Usage: python3 build_statusbar_only.py original.ipa output.ipa")
        sys.exit(2)
    print(json.dumps(build(Path(sys.argv[1]), Path(sys.argv[2])), indent=2))
