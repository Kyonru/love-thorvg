# Vector playground

This example explores capabilities that fixed PNG artwork does not provide.
Press `Tab` to switch between the experiments.

Run it from this directory:

```sh
/Applications/love.app/Contents/MacOS/love .
```

## 01 · SVG stencil

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

## 02 · Vector path morph versus PNG

ThorVG interpolates a vector path through circle, star, and rounded-square
keyframes. A real 96-by-96 PNG snapshot sits beside it at the same display
size. The comparison demonstrates that a single vector animation can produce
continuous states at the target resolution; a PNG needs a separate raster
frame for every state.

The pinned ThorVG SVG loader treats SVG documents as static artwork, so the
morph is stored as Lottie path keyframes and rendered through the same ThorVG
document API. The UI calls this out rather than implying SVG SMIL support.

- Left/right: pause and scrub the morph.
- Space: pause or resume automatic morphing.

Shared controls:

- `Tab`: switch experiments.
- `R`: reset the active state.
- Escape: quit.
