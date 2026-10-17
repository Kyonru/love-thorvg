# Quick start

Install a platform release, load one document, and make its lifetime explicit.

## Requirements

- LÖVE 11.x
- a desktop release for macOS ARM64, macOS x64, Linux x64, or Windows x64

## 1. Install the module

Download the archive for the computer that will run the game from the
[release page](https://github.com/Kyonru/love-thorvg/releases). Copy its entire
`love_thorvg/` directory beside your game entry point:

```text
my-game/
├── main.lua
├── assets/
│   └── mark.svg
└── love_thorvg/
    ├── init.lua
    ├── view.lua
    └── native/
        └── <platform>-<architecture>/
            └── <native-library>
```

Do not place the native library only inside a zipped `.love` archive. Keep it
on a real filesystem beside the game, or extract it before loading.

## 2. Load and draw an asset

```lua
local thorvg = require('love_thorvg')
local mark

function love.load()
  mark = thorvg.new('assets/mark.svg', {
    width = 320,
    height = 180,
    autoplay = false,
  })
end

function love.draw()
  mark:draw(80, 60)
end

function love.quit()
  mark:release()
end
```

`width` and `height` are raster dimensions, not just draw dimensions. Choose
values near the largest displayed size for a crisp result without unnecessary
CPU or texture work.

## 3. Animate Lottie

Lottie documents use the same object. Advance playback from `love.update`:

```lua
function love.update(dt)
  animation:update(dt)
end
```

Playback can be paused, restarted, or moved directly:

```lua
animation:pause()
animation:setProgress(0.5)
animation:seek(1.25)
animation:play()
```

## 4. Resize deliberately

Call `resize` only when the desired raster target changes. The document
reuses its allocation when the dimensions are unchanged.

```lua
function love.resize(width, height)
  local size = math.floor(math.min(width, height) * 0.4)
  animation:resize(size, size)
end
```

Next, learn how [relative images and fonts](../guides/assets.md) are resolved,
or review every constructor option in the [Lua API](../API.md).
