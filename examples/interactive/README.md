# Interactive vector lab

This example explores capabilities that fixed PNG artwork does not provide.
Press `Tab` to switch between the experiments.

Run it from this directory:

```sh
/Applications/love.app/Contents/MacOS/love .
```

## 01 · Interactive vending machine

The vending-machine Lottie contains nine authored hover segments and nine
selection segments. LÖVE performs hit-testing over the 3×3 product grid and
seeks the ThorVG document into the matching marker range. The animation remains
designer-authored while the application owns interaction and state.

Hover segments loop while a product is focused. Selecting a product plays its
one-shot dispense sequence, then returns to the focused product's hover state.
Rendering is capped at 30 updates per second while motion is active, cached for
repeated hover frames, and static while the machine is idle. To keep interaction
within a 120 FPS frame budget, the ThorVG texture is capped at 480×360 and
scaled to the display rectangle. The diagnostics rail reports FPS, draw calls,
GPU texture memory, Lua heap usage, ThorVG raster and upload time, render size,
and frame-cache activity.

- Mouse: hover a product; click to select it.
- Arrow keys: move keyboard focus through the product grid.
- Enter: select the focused product.
- Space: pause or resume motion.

## 02 · Interactive SVG map

The Dominican Republic SVG is rendered normally for display. A second,
color-coded derivative is rendered once and sampled on the CPU for pixel-precise
province hit testing. A small shader uses the same hit-map texture to highlight
hovered and selected regions, so interaction does not rerasterize the SVG or
require duplicate polygon geometry in Lua. Detached island paths share their
province's encoded color and behave as one target.

- Mouse: hover a province; click to select it.
- Arrow keys: browse provinces alphabetically.
- Enter: select the focused province.

## 03 · SVG stencil

The alpha channel of a ThorVG-rendered SVG populates LÖVE's stencil buffer.
The animated field is made from ordinary `love.graphics` calls and is only
visible where the SVG is opaque.

- Left/right: rotate the SVG mask.
- Up/down: adjust the alpha cutoff used by the stencil shader.
- `S`: enable or disable SVG clipping.
- Space: pause or resume the content animation.

The stencil is binary, so the shader discards pixels below the selected alpha
cutoff. A future exploration can compare this with a Canvas-based alpha mask,
which preserves partially transparent antialiased edges.

Shared controls:

- `Tab`: switch experiments.
- `R`: reset the active state.
- Escape: quit.

`main.lua` only connects LÖVE callbacks. `app.lua` coordinates shared layout
and experiment switching, while each implementation lives under
`experiments/`. Presentation helpers and colors live in `ui.lua` and
`theme.lua`. See [`assets/LICENSE.md`](assets/LICENSE.md) before redistributing
the sample artwork.
