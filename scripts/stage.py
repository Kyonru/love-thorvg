#!/usr/bin/env python3
"""Create a redistributable love-thorvg package from a Meson build."""

from __future__ import annotations

import argparse
import platform
import shutil
import sys
import zipfile
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
    parser.add_argument(
        "--version",
        help="optional release tag included in the archive name (for example v0.1.0)",
    )
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    system, architecture, library_name = target()
    build_dir = args.build_dir.resolve()
    output_dir = args.output_dir.resolve()
    matches = [path for path in build_dir.rglob(library_name) if path.is_file()]
    if not matches and system == "windows":
        matches = [
            path
            for path in build_dir.rglob(f"*{library_name}")
            if path.is_file()
        ]
    if not matches:
        candidates = sorted(
            str(path.relative_to(build_dir))
            for path in build_dir.rglob("*love_thorvg*")
            if path.is_file()
        )
        detail = f"; candidates: {', '.join(candidates)}" if candidates else ""
        raise SystemExit(f"could not find {library_name} under {build_dir}{detail}")

    name_parts = ["love-thorvg"]
    if args.version:
        name_parts.append(args.version)
    name_parts.extend((system, architecture))
    package_name = "-".join(name_parts)
    package = output_dir / package_name
    native = package / "love_thorvg" / "native" / f"{system}-{architecture}"
    native.mkdir(parents=True, exist_ok=True)

    shutil.copy2(root / "love_thorvg" / "init.lua", package / "love_thorvg" / "init.lua")
    shutil.copy2(root / "love_thorvg" / "view.lua", package / "love_thorvg" / "view.lua")
    shutil.copy2(matches[0], native / library_name)
    shutil.copy2(root / "README.md", package / "README.md")
    shutil.copy2(root / "LICENSE", package / "LICENSE")
    thorvg_license = root / "subprojects" / "thorvg" / "LICENSE"
    if not thorvg_license.is_file():
        thorvg_license = build_dir / "subprojects" / "thorvg" / "LICENSE"
    if not thorvg_license.is_file():
        raise SystemExit("could not find the ThorVG license in the source or build tree")
    shutil.copy2(thorvg_license, package / "THORVG-LICENSE")

    archive = output_dir / f"{package_name}.zip"
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as output:
        for path in sorted(package.rglob("*")):
            if path.is_file():
                output.write(path, path.relative_to(output_dir))
    print(archive)


if __name__ == "__main__":
    main()
