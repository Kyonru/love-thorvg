# API

## `thorvg.new(path, options)`

Loads an SVG or Lottie asset through `love.filesystem` and returns a `Document`.

Options:

- `width`, `height`: raster target size; defaults to the asset's intrinsic size.
- `autoplay`: start playback immediately; defaults to `true`.
- `loop`: wrap playback; defaults to `true`.
- `speed`: playback multiplier; defaults to `1`.
- `progress`: initial normalized progress; defaults to `0`.
- `filter`: LÖVE texture filter (`linear` or `nearest`); defaults to `linear`.
- `frameCache`: maximum number of rendered frames retained as GPU textures;
  defaults to `0` (disabled). Use a small value for interfaces that revisit
  frames while scrubbing.
- `threads`: ThorVG worker count. The first engine initialization fixes this
  value for the process; `0` lets rendering remain on the caller thread.
- `mimeType`: override format detection.
- `resourcePath`: native resource directory for external file references.
- `assetRoot`: virtual-filesystem directory used for relative image and font
  references; defaults to the document's directory.
- `fonts`: table mapping Lottie font-family names to virtual-filesystem paths.
- `assetResolver(source, kind)`: optional custom resolver. It receives the
  source string and either `"picture"` or `"font"`, and returns a string or
  LÖVE `Data` object containing the asset bytes. Returning `nil` declines it.

Public metadata fields are `duration`, `totalFrames`, `intrinsicWidth`, and
`intrinsicHeight`.

## Document methods

- `update(dt)`: advances playback and marks a changed frame dirty.
- `play()` / `pause()`: controls automatic playback.
- `setProgress(value)`: selects normalized animation progress.
- `seek(seconds)`: selects animation time.
- `resize(width, height)`: recreates the reusable target only when dimensions change.
- `render()`: rasterizes and uploads only when dirty; returns whether work occurred.
- `clearCache()`: releases all cached frame textures while keeping the document usable.
- `getCacheStats()`: returns `enabled`, `size`, `limit`, `hits`, `misses`, and
  `evictions`.
- `getRenderStats()`: returns render counts plus the last, total, and average
  rasterization and upload times in seconds. `lastCacheHit` identifies a cache
  lookup that skipped both stages.
- `resetRenderStats()`: resets the render timing counters.
- `draw(x, y, rotation, sx, sy, ox, oy)`: renders if needed, then draws the texture.
- `getImage()`: renders if needed and returns the reusable LÖVE `Image`.
- `release()`: immediately releases native and LÖVE resources; it is idempotent.

`Document` also has a finalizer, but explicit `release()` is recommended.

## Frame cache

The optional cache is a least-recently-used cache of completed LÖVE textures.
It avoids both ThorVG rasterization and texture upload when a previously visited
animation position is requested. Cache keys preserve progress to one thousandth
of an animation frame. Resizing or calling `clearCache()` releases every cached
texture.

Each entry uses approximately `width * height * 4` bytes of GPU memory, plus
driver overhead. For example, eight 256-by-256 frames require about 2 MiB. Keep
the default disabled for animations that move forward without revisiting frames.

## Pixel contract

The C ABI renders straight-alpha RGBA8 bytes directly into the `ImageData`
allocation. `Image:replacePixels` performs the CPU-to-GPU upload. The native API
is declared in `include/love_thorvg.h`; `love_thorvg_abi_version()` currently
returns `2`.

## External assets

Relative Lottie images are resolved from the animation's directory through
`love.filesystem`:

```text
ui/
├── success.json
└── images/
    └── confetti.png
```

For fonts referenced only by family name, provide an explicit mapping:

```lua
local animation = thorvg.new('ui/success.json', {
  fonts = {
    Inter = 'fonts/Inter-Regular.ttf',
  },
})
```

Use `assetResolver` for aliases, generated data, archives, or another virtual
asset source. Resolver data is copied by the native layer before the callback
returns.
