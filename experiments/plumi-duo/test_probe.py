"""Synthetic fixture tests: no commercial IPA or signing secrets in CI."""
import plistlib
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path
from plumi_probe import inspect_macho, inspect_ipa, packed_version


def thin_macho():
    build = struct.pack("<IIIIII", 0x32, 24, 2, 17 << 16,
                        (27 << 16) | (2 << 8), 0)
    section = bytearray(80)
    struct.pack_into("<I", section, 48, 4096)
    segment = struct.pack("<II16sQQQQiiII", 0x19, 152, b"__TEXT", 0,
                          4096, 0, 4096, 5, 5, 1, 0) + section
    commands = build + segment
    header = struct.pack("<IiiIIIII", 0xFEEDFACF, 0x100000c, 0, 2,
                         2, len(commands), 0, 0)
    return header + commands + bytes(4096 - len(header) - len(commands))


class TestProbe(unittest.TestCase):
    def test_version(self):
        self.assertEqual(packed_version((27 << 16) | (2 << 8)), "27.2.0")

    def test_header(self):
        report = inspect_macho(thin_macho())
        self.assertEqual(report["sdk_records"][0]["sdk"], "27.2.0")
        self.assertGreater(report["zero_header_padding"], 3000)

    def test_ipa_unchanged(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "fixture.ipa"
            info = {"CFBundleIdentifier": "dev.plumi.app",
                    "CFBundleExecutable": "Plumi",
                    "CFBundleVersion": "40", "UIDeviceFamily": [1, 2]}
            with zipfile.ZipFile(path, "w") as ipa:
                ipa.writestr("Payload/Plumi.app/Info.plist", plistlib.dumps(info))
                ipa.writestr("Payload/Plumi.app/Plumi", thin_macho())
            old = path.read_bytes()
            report = inspect_ipa(path)
            self.assertFalse(report["has_explicit_scene_manifest"])
            self.assertFalse(report["modified"])
            self.assertEqual(path.read_bytes(), old)


if __name__ == "__main__":
    unittest.main()
