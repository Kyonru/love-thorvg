#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
build_root=${1:-"$repo_root/build-lovejs"}
output_dir=${2:-"$repo_root/dist/web-example"}

# CMake resolves path-valued cache entries relative to its source directory.
# Normalize caller-provided paths so CI can safely use relative directories.
mkdir -p "$build_root" "$output_dir"
build_root=$(cd "$build_root" && pwd)
output_dir=$(cd "$output_dir" && pwd)

love_commit=32e0716b43a51686f5fa9ac04ca08b6410b698a5
megasource_commit=3bc0b46670a2912c02c54c6977b9510e64e89023
love_dir="$build_root/love"
megasource_dir="$build_root/megasource"
runtime_build_dir="$build_root/runtime"
core_build_dir="$build_root/core"

for command in git meson ninja cmake emcmake em++; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done

if [[ ! -d "$love_dir/.git" ]]; then
  git clone https://github.com/Davidobot/love.git "$love_dir"
fi
if [[ ! -d "$megasource_dir/.git" ]]; then
  git clone https://github.com/Davidobot/megasource.git "$megasource_dir"
fi

git -C "$love_dir" checkout --detach "$love_commit"
git -C "$megasource_dir" checkout --detach "$megasource_commit"
if ! git -C "$love_dir" apply --ignore-space-change --check "$repo_root/web/lovejs.patch" 2>/dev/null; then
  git -C "$love_dir" apply --ignore-space-change --reverse --check "$repo_root/web/lovejs.patch" >/dev/null 2>&1 || {
    echo "The pinned love.js patch does not apply cleanly." >&2
    exit 1
  }
else
  git -C "$love_dir" apply --ignore-space-change "$repo_root/web/lovejs.patch"
fi
if [[ ! -f "$core_build_dir/build.ninja" ]]; then
  meson setup "$core_build_dir" "$repo_root" \
    --cross-file "$repo_root/web/emscripten.ini" \
    -Dbuild_tests=false \
    -Dweb_harness=true \
    -Dthorvg:threads=false \
    -Dthorvg:simd=false \
    -Dthorvg:file=false \
    --wrap-mode=forcefallback
fi
meson compile -C "$core_build_dir"

emcmake cmake -S "$megasource_dir" -B "$runtime_build_dir" \
  -DMEGA_LOVE="$love_dir" \
  -DLOVE_JIT=0 \
  -DLOVE_MPG123=FALSE \
  -DLUA_BUILD_STATIC=ON \
  -DLOVEJS_COMPAT=1 \
  -DLOVE_THORVG_ROOT="$repo_root" \
  -DLOVE_THORVG_LIBRARY="$core_build_dir/liblove_thorvg.a" \
  -DTHORVG_LIBRARY="$core_build_dir/subprojects/thorvg/src/libthorvg-1.a" \
  -DCMAKE_PROJECT_INCLUDE="$repo_root/web/emscripten-project-options.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build "$runtime_build_dir" --target love --parallel

cp "$repo_root/examples/web/index.html" "$repo_root/examples/web/example.css" \
  "$repo_root/examples/web/example.js" "$output_dir/"
cp "$runtime_build_dir/love/love.js" "$runtime_build_dir/love/love.wasm" "$output_dir/"

emscripten_dir=$(dirname "$(command -v em++)")
"$emscripten_dir/tools/file_packager.py" "$output_dir/game.data" \
  --preload "$repo_root/examples/web/game@/" \
  --preload "$repo_root/examples/web/assets@/assets" \
  --preload "$repo_root/love_thorvg/init.lua@/love_thorvg/init.lua" \
  --preload "$repo_root/love_thorvg/view.lua@/love_thorvg/view.lua" \
  --preload "$repo_root/love_thorvg/web.lua@/love_thorvg/web.lua" \
  --js-output="$output_dir/game.js"

echo "Built the real LÖVE web example in $output_dir"
