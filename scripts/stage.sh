#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=${1:-"$root/build"}
arch=$(uname -m)

case "$(uname -s)" in
  Darwin) platform=macos; library=liblove_thorvg.dylib ;;
  Linux) platform=linux; library=liblove_thorvg.so ;;
  MINGW*|MSYS*|CYGWIN*) platform=windows; library=love_thorvg.dll ;;
  *) echo "unsupported platform" >&2; exit 1 ;;
esac

case "$arch" in
  x86_64|amd64) arch=x64 ;;
  aarch64) arch=arm64 ;;
esac

source_path=$(find "$build_dir" -type f -name "$library" -print -quit)
if [ -z "$source_path" ]; then
  echo "could not find $library under $build_dir" >&2
  exit 1
fi

destination="$root/love_thorvg/native/$platform-$arch"
mkdir -p "$destination"
cp "$source_path" "$destination/$library"
echo "staged $destination/$library"
