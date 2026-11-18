#!/usr/bin/env python3
"""Read-only IPA/Mach-O inspector for the Plumi Duo research branch.

Does not patch, decrypt, upload, or re-sign IPAs.
"""
import argparse
import hashlib
import json
import plistlib
import struct
import sys
import zipfile
from pathlib import Path


def packed_version(n):
    return f"{n >> 16}.{(n >> 8) & 255}.{n & 255}"


def inspect_macho(data):
    header = struct.unpack_from("<IiiIIIII", data)
    if header[0] != 0xFEEDFACF:
        raise ValueError("Expected thin arm64 Mach-O")
    count, size = header[4:6]
    end, pos = 32 + size, 32
    sdk = []
    first_section = len(data)
    for _ in range(count):
        cmd, cmdsize = struct.unpack_from("<II", data, pos)
        if cmdsize < 8 or pos + cmdsize > end:
            raise ValueError("Malformed load command")
        if cmd == 0x32:
            _, _, platform, minos, build_sdk, _ = struct.unpack_from("<IIIIII", data, pos)
            sdk.append({"platform": platform, "min_os": packed_version(minos),
                        "sdk": packed_version(build_sdk)})
        if cmd == 0x19 and cmdsize >= 72:
            name = data[pos + 8:pos + 24].split(b"\0", 1)[0]
            if name == b"__TEXT":
                nsections = struct.unpack_from("<I", data, pos + 64)[0]
                for index in range(nsections):
                    section = pos + 72 + 80 * index
                    if section + 80 <= pos + cmdsize:
                        offset = struct.unpack_from("<I", data, section + 48)[0]
                        if offset:
                            first_section = min(first_section, offset)
        pos += cmdsize
    if pos != end:
        raise ValueError("Load command length mismatch")
    return {"sdk_records": sdk, "load_command_end": end,
            "first_section_offset": first_section,
            "zero_header_padding": max(0, first_section - end)
            if all(v == 0 for v in data[end:first_section]) else 0}


def inspect_ipa(path):
    with zipfile.ZipFile(path) as ipa:
        names = ipa.namelist()
        apps = sorted({n.split("/")[1] for n in names
                       if n.startswith("Payload/") and n.count("/") > 1
                       and n.split("/")[1].endswith(".app")})
        if len(apps) != 1:
            raise ValueError("Expected one Payload/*.app")
        root = "Payload/" + apps[0] + "/"
        info = plistlib.loads(ipa.read(root + "Info.plist"))
        executable = ipa.read(root + info["CFBundleExecutable"])
    scene = info.get("UIApplicationSceneManifest")
    markers = ("SwiftUI", "GeometryReader", "userInterfaceIdiom",
               "UITraitCollection", "PaneLayout", "SubjectOverviewLayout",
               "iPad mini portrait")
    return {
        "file": path.name,
        "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest(),
        "identifier": info.get("CFBundleIdentifier"),
        "version": info.get("CFBundleShortVersionString"),
        "build": info.get("CFBundleVersion"),
        "plist_sdk": info.get("DTSDKName"),
        "minimum_os": info.get("MinimumOSVersion"),
        "device_families": info.get("UIDeviceFamily"),
        "has_explicit_scene_manifest": scene is not None,
        "macho": inspect_macho(executable),
        "string_markers": {marker: executable.count(marker.encode())
                           for marker in markers},
        "modified": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--output", type=Path)
    opts = parser.parse_args()
    try:
        report = json.dumps(inspect_ipa(opts.ipa), indent=2) + "\n"
    except Exception as exc:
        print("Inspection error:", exc, file=sys.stderr)
        return 1
    if opts.output:
        opts.output.write_text(report, encoding="utf-8")
    else:
        print(report, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
