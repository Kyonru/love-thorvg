# love-thorvg

[![Native artifacts](https://github.com/Kyonru/love-thorvg/actions/workflows/quality.yml/badge.svg)](https://github.com/Kyonru/love-thorvg/actions/workflows/quality.yml)
[![Documentation](https://github.com/Kyonru/love-thorvg/actions/workflows/pages.yml/badge.svg)](https://kyonru.github.io/love-thorvg/)
[![Release](https://github.com/Kyonru/love-thorvg/actions/workflows/release.yml/badge.svg)](https://github.com/Kyonru/love-thorvg/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-20c9b5.svg)](LICENSE)

Render SVG and Lottie animations in **LÖVE 11.x** with ThorVG. `love-thorvg`
loads assets through `love.filesystem`, renders them into a reusable texture,
and only redraws when animation progress or output size changes.

It works without a custom LÖVE build and is designed for UI illustrations,
icons, loaders, onboarding animation, and other modest animation workloads.

## Availability

[GitHub releases](https://github.com/Kyonru/love-thorvg/releases) provide tested
packages for macOS ARM64, macOS x64, Linux x64, and Windows x64. The repository
also includes an `all-desktop` bundle for projects that package several targets,
and a ready-to-use macOS ARM64 library.

An [experimental web backend](https://kyonru.github.io/love-thorvg/experimental/web/)
compiles the same ThorVG C ABI to WebAssembly. It currently requires a custom
love.js build; see the [live proof](https://kyonru.github.io/love-thorvg/experimental/web-proof/)
and the explicit support boundary before adopting it.

Supported assets:

- SVG files;
- Lottie JSON files;
- embedded or relative PNG images inside Lottie files;
- external Lottie fonts with an explicit family-to-path mapping.

Relative assets are loaded through `love.filesystem`, so they work from normal
game directories and `.love` archives.

## Try the examples

On an Apple Silicon Mac with LÖVE installed in `/Applications`:

```sh
cd examples/asset-browser
/Applications/love.app/Contents/MacOS/love .
```

Use any arrow key to rotate between the SVG and Lottie examples. Press `R` to
restart the active animation.

To explore SVG hit testing, SVG-driven clipping, and marker-driven Lottie
interaction:

```sh
cd examples/interactive
/Applications/love.app/Contents/MacOS/love .
```

This playground includes an interactive map of the Dominican Republic with a
Lottie path-drawing entrance, pixel-precise SVG hit testing, and spring-loaded
region selection; an SVG-driven stencil; and an interactive vending machine.
Hover or keyboard-focus map regions and vending products, then click or press
Enter to select them. Press `Tab` to switch experiments.

Each example includes an `assets/LICENSE.md` manifest linking its local files
and recording the available source and licensing information.

## Install

Download the archive for your platform from the
[release page](https://github.com/Kyonru/love-thorvg/releases), then copy the
complete `love_thorvg/` directory into your game:

```text
my-game/
├── main.lua
└── love_thorvg/
    ├── init.lua
    └── native/
        └── macos-arm64/
            └── liblove_thorvg.dylib
```

Keep the native directory intact so the wrapper can select the correct library.
Use the `all-desktop` ZIP if the same project tree produces packages for several
operating systems; otherwise the smaller target-specific ZIP is sufficient.
To load a library from a custom location, set `LOVE_THORVG_LIBRARY` to its
absolute path before launching the game.

Native libraries cannot be loaded from inside a zipped `.love` archive. In a
fused or distributed game, place the native library beside the executable or
extract it to a real filesystem path.

## Use

```lua
local thorvg = require('love_thorvg')
local animation

function love.load()
  animation = thorvg.new('assets/animation.json', {
    width = 256,
    height = 256,
    autoplay = true,
    loop = true,
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

External images are resolved relative to the animation file. Map fonts that are
referenced only by family name:

```lua
local animation = thorvg.new('ui/success.json', {
  fonts = {
    Inter = 'fonts/Inter-Regular.ttf',
  },
})
```

Use the same API for SVG files:

```lua
local logo = thorvg.new('assets/logo.svg', {
  width = 320,
  height = 180,
  autoplay = false,
})
```

## UI integration

Resize and draw the document inside an immediate-mode view callback:

```lua
ui.renderView(function(x, y, width, height)
  animation:resize(width, height)
  animation:draw(x, y)
end)
```

If `renderView` accepts a callback directly:

```lua
local asView = require('love_thorvg.view')
ui.renderView(asView(animation))
```

## Playback control

```lua
animation:pause()
animation:setProgress(0.5) -- normalized position from 0 to 1
animation:seek(1.25)       -- position in seconds
animation:play()
```

Calling `render`, `draw`, or `getImage` repeatedly without changing progress or
size reuses the existing frame and does not rerasterize or re-upload it.

For timelines that frequently revisit frames, enable a small bounded cache:

```lua
local animation = thorvg.new('assets/animation.json', {
  width = 256,
  height = 256,
  frameCache = 8,
})
```

Cached frames avoid both rasterization and upload. The cache uses approximately
`width * height * 4 * frameCache` bytes of GPU memory and is cleared whenever
the document is resized. Leave it disabled for ordinary forward playback.

## Runtime considerations

Rendering currently uses ThorVG's CPU backend followed by a CPU-to-GPU texture
upload. This is a practical fit for several UI animations, but not hundreds of
large animations updating every frame. Reuse document instances, keep output
dimensions close to their displayed size, and call `release()` when finished.

Read the [documentation](https://kyonru.github.io/love-thorvg/) for setup,
assets, examples, performance guidance, and the complete API. See
[CHANGELOG.md](CHANGELOG.md) for release notes.

## Contributing

Build instructions, architecture notes, verification steps, and the roadmap are
in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

`love-thorvg` is MIT licensed. Distributed builds include ThorVG and must retain
its license notices.
