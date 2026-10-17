# Experimental web backend

!!! warning "Experimental and not in the desktop release archives"

    Web support uses a custom, pinned love.js build. The repository builds and
    tests that runtime end to end, but the backend is still experimental rather
    than a general-purpose LÖVE browser distribution. Test your exported game.

Stock browser ports of LÖVE use PUC Lua 5.1 rather than LuaJIT. That means the
desktop adapter's FFI calls cannot work in a browser. `love-thorvg` solves this
with a small built-in Lua C module instead of trying to emulate FFI in JavaScript.

```mermaid
flowchart LR
    A[Game Lua] --> B[love_thorvg/web.lua]
    B --> C[preloaded Lua C module]
    C --> D[love-thorvg C ABI]
    D --> E[ThorVG CPU renderer]
    E --> F[RGBA in WASM memory]
    F --> G[LÖVE ImageData and texture]
```

The architecture has one WebAssembly module and one memory arena. ThorVG is
statically linked into the same custom love.js runtime as LÖVE. The binding
returns RGBA bytes to Lua, and `love.image.newImageData` creates the uploadable
image. No JavaScript bridge is involved during normal Lua rendering.

## What is implemented

- SVG and Lottie decoding and CPU rasterization under Emscripten;
- the same `require('love_thorvg')`, `new`, playback, resize, cache, stats, image,
  and draw API used on desktop;
- assets read through `love.filesystem`, including resolver callbacks for
  relative images and mapped fonts;
- explicit release plus a userdata finalizer as a safety net;
- automated Node proof, an automated Chromium run of the real LÖVE game, and a
  live browser example on the documentation site.

Threads and SIMD are disabled in the first backend. Raster pixels cross one
additional WASM-to-Lua string copy before becoming `ImageData`; size documents
conservatively and use frame caching for repeatedly visited frames.

[Run the live LÖVE example](/love-thorvg/experimental/web-demo/){ .md-button .md-button--primary }

The example executes `examples/web/game/main.lua` in the custom browser
runtime. It loads Lottie artwork shared with the native examples, advances it
in `love.update`, draws it in `love.draw`, and accepts keyboard input to switch
assets.

## Build the verified WebAssembly core

Install Emscripten, Meson, and Ninja, then run:

```sh
meson setup build-web \
  --cross-file web/emscripten.ini \
  -Dbuild_tests=false \
  -Dweb_harness=true \
  -Dthorvg:threads=false \
  -Dthorvg:simd=false \
  -Dthorvg:file=false
meson compile -C build-web
node tests/web_wasm_test.mjs "$PWD/build-web/love_thorvg_web.js"
```

This produces `love_thorvg_web.js` and `love_thorvg_web.wasm`. The harness is
useful for testing the C ABI in isolation, but it is not the published example.

## Build the real LÖVE example

With Emscripten 6.0.12, Meson, Ninja, and CMake available, run:

```sh
./scripts/build_web_example.sh
python3 -m http.server 8000 --directory dist/web-example
```

The script checks out pinned LÖVE and megasource revisions, applies the small
compatibility patch in `web/lovejs.patch`, builds ThorVG and LÖVE into one
WebAssembly module, and packages `examples/web/game` with the Lua adapter and
repository Lottie assets. Open `http://localhost:8000` to run it.

## Integrate it with love.js

The automated build uses a source build of love.js with LuaJIT disabled, as
required by that port. It adds these translation units to the final Emscripten
target:

```text
native/love_thorvg.cpp
web/love_thorvg_lua.cpp
web/register_module.cpp
```

Also add the ThorVG static dependency, its include paths, and `include/` from
this repository. Build ThorVG with the same options shown above. After love.js
creates its `lua_State`, call:

```cpp
love_thorvg_register_web_module(luaState);
```

That installs `love_thorvg_web` in `package.preload`. Include the complete
`love_thorvg/` directory in the game's virtual filesystem. At runtime,
`love_thorvg/init.lua` detects `love.system.getOS() == 'Web'` and selects the
non-FFI adapter automatically; game code remains unchanged.

Keep all three C++ files and ThorVG in the final link. If dead-code elimination
removes the registration function, explicitly export or call it from the same
translation unit that owns the Lua state.

## Automated verification

Every web-backend build runs two complementary checks. The low-level Node test
in `tests/web_wasm_test.mjs`:

1. instantiates the Emscripten module and checks ABI version 2;
2. decodes an SVG from bytes and verifies its rendered RGBA pixels;
3. decodes a Lottie document, checks its timeline metadata, renders progress
   `0.5`, and verifies non-transparent output; and
4. prints stable SHA-256 prefixes for both rendered buffers.

The browser test in `tests/web_love_test.mjs` then starts the packaged game in
headless Chromium. It waits for a marker printed by Lua, verifies LÖVE reports
`OS=Web`, compares two canvas captures to prove the Lottie animation advances,
sends an Arrow Right event, and waits for Lua to load the Thanksgiving Turkey
asset. Page errors and console errors fail the run.

Together these tests cover the pinned `wasm32` build, SVG and Lottie decoding,
PUC Lua 5.1 startup, automatic backend selection, `love.filesystem` reads,
ThorVG-to-LÖVE texture upload, animation, drawing, and browser input. Successful
GitHub Actions runs also publish the built HTML, JavaScript, WASM, and screenshot
as the `experimental-web-proof` workflow artifact.

## Current boundary

The example runtime is a reproducible proof build, not a maintained replacement
for upstream LÖVE or a stable downloadable web SDK. It is single-threaded and
disables audio, sound, joystick, physics, video, and thread modules. Keyboard, pointer,
filesystem packaging, LÖVE callbacks, texture upload, and rendering are covered
by the browser proof. Persistence, audio, performance on constrained devices,
and broad browser compatibility still require more work.
