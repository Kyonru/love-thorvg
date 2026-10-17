# Contributing

Thanks for helping make ThorVG straightforward to use from LÖVE. Changes should
keep the Lua API easy to copy into a game and keep ThorVG behind the small,
versioned C ABI in `include/love_thorvg.h`.

## Development setup

Requirements:

- LÖVE 11.x
- Python 3
- a C++17 compiler
- Ninja
- Git

Create an isolated Meson environment from the repository root:

```sh
python3 -m venv .venv
.venv/bin/pip install meson
```

Build the native library, run the tests, and stage the result into the Lua
package:

```sh
PATH="$PWD/.venv/bin:$PATH" ./scripts/build.sh
```

The build fetches the exact ThorVG revision declared in
`subprojects/thorvg.wrap`. Generated ThorVG sources, package caches, build
directories, and the local Python environment are ignored by Git.

To keep build output elsewhere:

```sh
LOVE_THORVG_BUILD_DIR=/tmp/love-thorvg-build \
  PATH="$PWD/.venv/bin:$PATH" ./scripts/build.sh
```

## Architecture

```text
SVG / Lottie bytes
        ↓
ThorVG CPU canvas → reusable LÖVE ImageData → Image:replacePixels
                                                ↓
                                  draw directly or in ui.renderView
```

The native boundary accepts document bytes rather than paths so assets loaded
through LÖVE's virtual filesystem work in development and `.love` archives.
ThorVG is pinned to an exact 1.2.0 source revision and built with its CPU, SVG,
Lottie, and bundled PNG implementations. The bundled PNG decoder keeps release
artifacts independent of Homebrew or another system package manager.

## Run the example

On macOS with LÖVE installed in `/Applications`:

```sh
cd examples/asset-browser
/Applications/love.app/Contents/MacOS/love .
```

The repository currently includes a macOS ARM64 library. Other platforms and
architectures must run the build first and stage their matching library.

If the library is stored somewhere else, point the wrapper to it explicitly:

```sh
LOVE_THORVG_LIBRARY=/absolute/path/to/liblove_thorvg.dylib \
  /Applications/love.app/Contents/MacOS/love .
```

## Verification

`scripts/build.sh` runs the native test suite automatically. To rerun only the
tests after configuring a default `build/` directory:

```sh
PATH="$PWD/.venv/bin:$PATH" meson compile -C build
PATH="$PWD/.venv/bin:$PATH" meson test -C build --print-errorlogs
```

The native suite must continue to cover:

- SVG loading and RGBA rendering;
- Lottie loading, duration, frame count, and rendering;
- changing the render target size while reusing a document.

## Performance benchmark

Run the reproducible CPU-rasterization and texture-upload benchmark with:

```sh
./scripts/benchmark.sh
```

It renders the same Lottie animation at 128, 256, and 512 pixels and prints
CSV rows containing average rasterization, upload, and combined frame times.
The timers measure synchronous work inside `Document:render()`; GPU driver work
deferred beyond `Image:replacePixels` is not included. Record the LÖVE version,
OS, CPU/GPU, power state, and build type when comparing results.

For Lua or packaging changes, also launch `examples/asset-browser` and confirm that the
native library is discovered without setting `LOVE_THORVG_LIBRARY`. Use the
arrow keys to visit both the SVG and Lottie examples, and press `R` to verify
that Lottie playback restarts from its first frame.

Changes to interaction, frame caching, or render statistics must also be tested
in `examples/interactive`. Hover at least one product through two complete
loops, activate it once, and verify the second hover loop reports cache hits.
On the map experiment, hover and select both a mainland province and a detached
island, then use the arrow keys and Enter to verify keyboard selection. Press
`R` and confirm the Lottie path-drawing entrance replays before returning to the
interactive SVG. Repeatedly select different regions and confirm each spring
settles without shifting the base map or causing a ThorVG raster/upload spike.
Pause the map with Space, then use an arrow and Enter; keyboard selection must
resume and complete the spring rather than freezing its first frame.

## Documentation

The documentation site uses Zensical. Install the pinned dependency and run a
strict local build from the repository root:

```sh
.venv/bin/pip install -r requirements-docs.txt
.venv/bin/zensical build --clean --strict
```

Generated files are written to `site/` and are not committed. Changes pushed
to `main` under `docs/`, `zensical.toml`, or the documentation workflow deploy
automatically to GitHub Pages.

Example assets need an entry in that example's `assets/LICENSE.md`. Link the
local file and its original source page, name the applicable license, and record
the creator when known. If the source or license cannot be verified, say so and
do not present the asset as cleared for redistribution.

## Design constraints

- Do not require a patched LÖVE build.
- Keep the CPU backend functional before adding optional GPU backends.
- Render directly into reusable `ImageData` memory; avoid intermediate Lua
  strings or per-frame texture allocation.
- Do not rerasterize or upload when animation progress and target size are
  unchanged.
- Load document bytes through `love.filesystem` so normal `.love` assets work.
- Release native and LÖVE resources explicitly in examples and tests.
- Keep distributed native libraries self-contained; optional image decoders
  must not introduce package-manager paths or undeclared runtime dependencies.
- Keep the web backend free of LuaJIT FFI. Its extra RGBA string copy is an
  explicit experimental portability tradeoff, not a desktop-path regression.

## Native ABI changes

The LuaJIT declaration in `love_thorvg/init.lua` must match
`include/love_thorvg.h`. When changing the ABI:

1. update the public header and implementation together;
2. update the LuaJIT `ffi.cdef` block;
3. extend the native tests;
4. increment `love_thorvg_abi_version()` for an incompatible change;
5. rebuild every shipped platform library.

Never allow a C++ exception to cross the C ABI. Return a
`love_thorvg_result` value and populate the caller-provided error buffer.

## Platform artifacts

Staged libraries use these directories:

```text
love_thorvg/native/macos-arm64/liblove_thorvg.dylib
love_thorvg/native/macos-x64/liblove_thorvg.dylib
love_thorvg/native/linux-x64/liblove_thorvg.so
love_thorvg/native/windows-x64/love_thorvg.dll
```

Run the native tests on the artifact's actual target architecture. Release
bundles must retain ThorVG's license notices. Native libraries cannot be loaded
from inside a zipped `.love` archive, so distribution documentation must tell
users to place the library beside the executable or extract it to a real path.

The release workflow runs `scripts/combine_packages.py` after all four builds.
Run `python3 -m unittest tests.test_combine_packages` when changing packaging.

## Experimental web verification

With Emscripten on `PATH`, build and run the same proof used by CI:

```sh
meson setup build-web --cross-file web/emscripten.ini -Dbuild_tests=false \
  -Dweb_harness=true -Dthorvg:threads=false -Dthorvg:simd=false -Dthorvg:file=false
meson compile -C build-web
node tests/web_wasm_test.mjs "$PWD/build-web/love_thorvg_web.js"
```

Web changes must preserve SVG and Lottie pixel proof. Changes to the Lua bridge
must also be tested in a custom love.js build because the standalone harness
does not initialize LÖVE or the Lua module.

## Using the library in a game

Copy the complete `love_thorvg/` directory into the game and load it normally:

```lua
local thorvg = require('love_thorvg')
local animation

function love.load()
  animation = thorvg.new('assets/animation.json', {
    width = 256,
    height = 256,
  })
end

function love.update(dt)
  animation:update(dt)
end

function love.draw()
  animation:draw(100, 100)
end

function love.quit()
  animation:release()
end
```

## Pull requests

Keep changes focused and describe which platforms were built and tested. Do not
commit `build/`, `.venv/`, the downloaded `subprojects/thorvg/` checkout, or
Meson's package cache. Commit a staged native library only when intentionally
updating a distributed platform artifact.

## Releases

Versioned releases are built for all supported targets from `v*` tags. See
[docs/RELEASING.md](docs/RELEASING.md) for the preparation checklist, tag
workflow, artifact layout, and recovery guidance.

## Roadmap

- [x] CI-built release artifacts for macOS ARM64/x64, Windows x64, and Linux x64
- [x] external Lottie image and font resolution through `love.filesystem`
- [x] optional bounded frame cache for scrub-heavy interfaces
- [x] rasterization and upload benchmarks
- [x] investigation of OpenGL and WebGPU interop after the CPU API is stable;
  see [docs/GPU_BACKENDS.md](docs/GPU_BACKENDS.md)
