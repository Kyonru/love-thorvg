#!/usr/bin/env python3
"""Create a redistributable love-thorvg package from a Meson build."""

from __future__ import annotations

import argparse
import platform
import shutil
import sys
from pathlib import Path


def target() -> tuple[str, str, str]:
    systems = {
        "darwin": ("macos", "liblove_thorvg.dylib"),
        "linux": ("linux", "liblove_thorvg.so"),
        "win32": ("windows", "love_thorvg.dll"),
    }
    if sys.platform not in systems:
        raise SystemExit(f"unsupported platform: {sys.platform}")

    architecture = platform.machine().lower()
    architectures = {
        "aarch64": "arm64",
        "arm64": "arm64",
        "amd64": "x64",
        "x86_64": "x64",
    }
    if architecture not in architectures:
        raise SystemExit(f"unsupported architecture: {architecture}")

    system, library = systems[sys.platform]
    return system, architectures[architecture], library


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("build_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    system, architecture, library_name = target()
    matches = [path for path in args.build_dir.rglob(library_name) if path.is_file()]
    if not matches:
        raise SystemExit(f"could not find {library_name} under {args.build_dir}")

    package_name = f"love-thorvg-{system}-{architecture}"
    package = args.output_dir / package_name
    native = package / "love_thorvg" / "native" / f"{system}-{architecture}"
    native.mkdir(parents=True, exist_ok=True)

    shutil.copy2(root / "love_thorvg" / "init.lua", package / "love_thorvg" / "init.lua")
    shutil.copy2(root / "love_thorvg" / "view.lua", package / "love_thorvg" / "view.lua")
    shutil.copy2(matches[0], native / library_name)
    shutil.copy2(root / "README.md", package / "README.md")
    shutil.copy2(root / "LICENSE", package / "LICENSE")
    shutil.make_archive(str(args.output_dir / package_name), "zip", args.output_dir, package_name)
    print(args.output_dir / f"{package_name}.zip")


if __name__ == "__main__":
    main()
