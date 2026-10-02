#!/usr/bin/env sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build_dir=${LOVE_THORVG_BUILD_DIR:-"$root/build"}

if [ -f "$build_dir/build.ninja" ]; then
  meson setup "$build_dir" "$root" --reconfigure --wrap-mode=forcefallback
else
  meson setup "$build_dir" "$root" --wrap-mode=forcefallback
fi
meson compile -C "$build_dir"
meson test -C "$build_dir" --print-errorlogs
"$root/scripts/stage.sh" "$build_dir"
