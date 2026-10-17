#!/usr/bin/env python3
"""Combine the four native release packages into one validated desktop bundle."""

from __future__ import annotations

import argparse
import posixpath
import zipfile
from pathlib import Path, PurePosixPath

PLATFORMS = ("macos-arm64", "macos-x64", "linux-x64", "windows-x64")
SHARED = {
    "love_thorvg/init.lua",
    "love_thorvg/view.lua",
    "README.md",
    "LICENSE",
    "THORVG-LICENSE",
}


def canonical_common(name: str, data: bytes) -> bytes:
    """Normalize checkout-specific line endings before validation and output."""
    if name.endswith((".lua", ".md", ".txt")) or name in {"LICENSE", "THORVG-LICENSE"}:
        return data.replace(b"\r\n", b"\n")
    return data


def normalized_members(archive: Path) -> dict[str, bytes]:
    with zipfile.ZipFile(archive) as source:
        files = [item for item in source.infolist() if not item.is_dir()]
        if not files:
            raise ValueError(f"{archive.name} is empty")
        roots = {PurePosixPath(item.filename).parts[0] for item in files}
        if len(roots) != 1:
            raise ValueError(f"{archive.name} must have exactly one top-level directory")
        root = next(iter(roots))
        result: dict[str, bytes] = {}
        for item in files:
            path = PurePosixPath(item.filename)
            if path.is_absolute() or ".." in path.parts or posixpath.normpath(item.filename) != item.filename:
                raise ValueError(f"unsafe archive member in {archive.name}: {item.filename}")
            relative = PurePosixPath(*path.parts[1:]).as_posix()
            if not relative:
                continue
            if relative in result:
                raise ValueError(f"duplicate archive member in {archive.name}: {relative}")
            result[relative] = source.read(item)
        if not SHARED.issubset(result):
            missing = ", ".join(sorted(SHARED - result.keys()))
            raise ValueError(f"{archive.name} is missing shared files: {missing}")
        if not any(name.startswith("love_thorvg/native/") for name in result):
            raise ValueError(f"{archive.name} contains no native library")
        return result


def combine(input_dir: Path, output_dir: Path, version: str) -> Path:
    packages = {
        platform: input_dir / f"love-thorvg-{version}-{platform}.zip"
        for platform in PLATFORMS
    }
    missing = [path.name for path in packages.values() if not path.is_file()]
    if missing:
        raise ValueError("missing packages: " + ", ".join(missing))

    merged: dict[str, bytes] = {}
    baseline: dict[str, bytes] | None = None
    for platform, archive in packages.items():
        members = normalized_members(archive)
        common = {
            name: canonical_common(name, data)
            for name, data in members.items()
            if not name.startswith("love_thorvg/native/")
        }
        if baseline is None:
            baseline = common
            merged.update(baseline)
        else:
            changed = sorted(
                name for name in baseline.keys() | common.keys()
                if baseline.get(name) != common.get(name)
            )
            if changed:
                raise ValueError(f"{archive.name} has mismatched shared files: {', '.join(changed)}")
        for name, data in members.items():
            if not name.startswith("love_thorvg/native/"):
                continue
            if name in merged and merged[name] != data:
                raise ValueError(f"conflicting native file from {platform}: {name}")
            merged[name] = data

    output_dir.mkdir(parents=True, exist_ok=True)
    bundle_name = f"love-thorvg-{version}-all-desktop"
    output = output_dir / f"{bundle_name}.zip"
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in sorted(merged):
            archive.writestr(f"{bundle_name}/{name}", merged[name])
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--version", required=True, help="release tag, for example v0.1.0")
    args = parser.parse_args()
    try:
        print(combine(args.input_dir, args.output_dir, args.version))
    except ValueError as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
