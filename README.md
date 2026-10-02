# love-thorvg

ThorVG-powered SVG and Lottie rendering for **LÖVE 11.x**. `love-thorvg` keeps
ThorVG behind a small C ABI, renders into a reusable `ImageData` allocation,
and updates a reusable LÖVE texture only when the requested frame changes.

The first backend is intentionally CPU-only. It requires no LÖVE fork and is a
good fit for UI illustrations and a modest number of animations. It is not
intended for hundreds of large, continuously changing animations.

## Status

This is an initial macOS-ready implementation. The public Lua API and native ABI
are versioned, but prebuilt release packaging for macOS, Windows, and Linux is
the next milestone. ThorVG is pinned to an exact 1.2.0 source revision.

## Build

Requirements: a C++17 compiler, Meson 1.3+, Ninja, and Git.

```sh
./scripts/build.sh
```

Meson downloads the pinned ThorVG source, builds its CPU renderer with the SVG
and Lottie loaders, runs the native smoke test, and stages the dynamic library:

```text
love_thorvg/native/macos-arm64/liblove_thorvg.dylib
love_thorvg/native/macos-x64/liblove_thorvg.dylib
love_thorvg/native/linux-x64/liblove_thorvg.so
love_thorvg/native/windows-x64/love_thorvg.dll
```

Set `LOVE_THORVG_BUILD_DIR` to use a build directory outside the checkout. At
runtime, `LOVE_THORVG_LIBRARY` can point to an explicit native library.

## Install in a game

Copy the complete `love_thorvg/` directory, including the native library for
your target, into the game:

```text
my-game/
├── main.lua
└── love_thorvg/
    ├── init.lua
    └── native/
        └── macos-arm64/
            └── liblove_thorvg.dylib
```

Native libraries cannot be loaded from inside a zipped `.love` archive. For a
fused/distributed game, place the platform library beside the executable or set
`LOVE_THORVG_LIBRARY` to its extracted location.

## Use

```lua
local thorvg = require('love_thorvg')
local spinner

function love.load()
  spinner = thorvg.new('ui/spinner.json', {
    width = 128,
    height = 128,
    autoplay = true,
    loop = true,
  })
end

function love.update(dt)
  spinner:update(dt)
end

function love.draw()
  spinner:draw(32, 32)
end

function love.quit()
  spinner:release()
end
```

For immediate-mode UI code, draw the document inside the view callback:

```lua
ui.renderView(function(x, y, width, height)
  spinner:resize(width, height)
  spinner:draw(x, y)
end)
```

If `renderView` accepts a callback value directly:

```lua
local asView = require('love_thorvg.view')
ui.renderView(asView(spinner))
```

Call `setProgress(0..1)` or `seek(seconds)` for externally controlled playback.
Calling `render`, `draw`, or `getImage` repeatedly without changing progress or
size does not rerasterize or re-upload the texture.

See [docs/API.md](docs/API.md) for the complete initial API.

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
Embedded assets work today; Lottie files that reference external images need a
future LÖVE-filesystem asset resolver.

## Roadmap

- CI-built release artifacts for macOS, Windows, and Linux
- external Lottie image/font resolution through `love.filesystem`
- optional bounded frame cache for scrub-heavy interfaces
- benchmarks and upload/raster timing counters
- investigation of OpenGL/WebGPU interop after the CPU API is stable

## License

`love-thorvg` is MIT licensed. ThorVG is fetched and built separately under its
own MIT license; release bundles must retain ThorVG's license notices.
