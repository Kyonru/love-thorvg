# Performance

The production path uses ThorVG's CPU renderer, followed by one upload into a
reusable LÖVE texture when the document changes.

## Keep raster targets honest

Rendering cost and texture memory grow with pixel area. A document rendered at
512 × 512 has four times as many pixels as one rendered at 256 × 256. Size the
raster target near its largest displayed size rather than the window size.

## Reuse documents

Create a document once, update it, and draw it many times. Calls to `render`,
`draw`, or `getImage` reuse the current frame when progress and dimensions are
unchanged.

Call `release()` when the document is no longer needed. This immediately frees
the native document, `ImageData`, textures, and cached frames.

## Cache revisited frames

Enable `frameCache` for timelines that repeatedly scrub or jump among a small
set of frames:

```lua
local animation = thorvg.new('dial.json', {
  width = 256,
  height = 256,
  frameCache = 8,
})
```

Each entry uses approximately `width × height × 4` bytes of GPU memory, plus
driver overhead. Sequential playback rarely benefits because every frame is
new. Resizing clears the cache.

## Measure the two stages

`getRenderStats()` reports rasterization and upload timing separately, along
with cache hits and total render counts. Use it to distinguish complex vector
artwork from texture-upload pressure.

The repository benchmark runs the same Lottie asset at several sizes:

```sh
./scripts/benchmark.sh
```

For the reasoning behind the CPU path and the requirements for future
zero-copy rendering, read the [GPU backend investigation](../GPU_BACKENDS.md).
