#!/usr/bin/env python3
"""Check that a release tag matches the project version and changelog."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: check_release.py v<version>")

    tag = sys.argv[1]
    if not re.fullmatch(r"v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?", tag):
        raise SystemExit(f"invalid release tag: {tag!r}")

    root = Path(__file__).resolve().parent.parent
    meson = (root / "meson.build").read_text(encoding="utf-8")
    match = re.search(r"\bversion:\s*'([^']+)'", meson)
    if not match:
        raise SystemExit("could not find the project version in meson.build")

    version = tag.removeprefix("v")
    if version != match.group(1):
        raise SystemExit(
            f"tag {tag!r} does not match meson.build version {match.group(1)!r}"
        )

    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    if not re.search(rf"^## (?:\[{re.escape(version)}\]|v{re.escape(version)})\b", changelog, re.MULTILINE):
        raise SystemExit(f"CHANGELOG.md has no entry for {tag}")

    print(f"release metadata is ready for {tag}")


if __name__ == "__main__":
    main()
