from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

from scripts.combine_packages import PLATFORMS, combine


class CombinePackagesTest(unittest.TestCase):
    def make_package(self, directory: Path, platform: str, *, readme: bytes = b"same") -> Path:
        name = f"love-thorvg-v0.1.0-{platform}"
        output = directory / f"{name}.zip"
        library = {"macos-arm64": "liblove_thorvg.dylib", "macos-x64": "liblove_thorvg.dylib",
                   "linux-x64": "liblove_thorvg.so", "windows-x64": "love_thorvg.dll"}[platform]
        shared = {"love_thorvg/init.lua": b"init", "love_thorvg/view.lua": b"view",
                  "README.md": readme, "LICENSE": b"license", "THORVG-LICENSE": b"thorvg"}
        with zipfile.ZipFile(output, "w") as archive:
            for path, contents in shared.items(): archive.writestr(f"{name}/{path}", contents)
            archive.writestr(f"{name}/love_thorvg/native/{platform}/{library}", platform.encode())
        return output

    def test_combines_all_platforms(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for platform in PLATFORMS: self.make_package(root, platform)
            output = combine(root, root, "v0.1.0")
            with zipfile.ZipFile(output) as archive:
                names = archive.namelist()
            for platform in PLATFORMS:
                self.assertTrue(any(f"/native/{platform}/" in name for name in names))
            self.assertEqual(sum(name.endswith("/README.md") for name in names), 1)

    def test_rejects_mismatched_shared_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for platform in PLATFORMS:
                self.make_package(root, platform, readme=b"different" if platform == "linux-x64" else b"same")
            with self.assertRaisesRegex(ValueError, "mismatched shared files"):
                combine(root, root, "v0.1.0")

    def test_normalizes_windows_line_endings(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for platform in PLATFORMS:
                self.make_package(root, platform, readme=b"same\r\n" if platform == "windows-x64" else b"same\n")
            output = combine(root, root, "v0.1.0")
            with zipfile.ZipFile(output) as archive:
                readme = next(name for name in archive.namelist() if name.endswith("/README.md"))
                self.assertEqual(archive.read(readme), b"same\n")

    def test_rejects_unsafe_member(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for platform in PLATFORMS:
                package = self.make_package(root, platform)
                if platform == "linux-x64":
                    with zipfile.ZipFile(package, "a") as archive:
                        archive.writestr("love-thorvg-v0.1.0-linux-x64/../escape", b"no")
            with self.assertRaisesRegex(ValueError, "unsafe archive member"):
                combine(root, root, "v0.1.0")


if __name__ == "__main__":
    unittest.main()
