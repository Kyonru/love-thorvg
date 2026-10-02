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

## 02 · Coffee packaging match cut

This original “Night Shift” packaging loop is inspired by
[SVGator's coffee cup animation](https://dribbble.com/shots/24842984-Coffee-Cup-Packaging-Design-Animated-Patterns),
without copying its branding or artwork. The cup stays as the visual anchor
while its silhouette, lid, steam, palette, and layered package pattern match-cut
between three moods.

That coordination is the useful distinction. A single polygon is easier to
animate directly with `love.graphics` and a tweening library. Here, one imported
designer timeline owns several Bézier shapes and independent tracks together.
The same sequence as a sprite sheet would require 181 raster frames at every
target resolution; ThorVG rerasterizes the source artwork at the requested size.

The pinned ThorVG SVG loader treats SVG documents as static artwork, so this
animated example is stored as a Lottie timeline and rendered through the same
ThorVG document API used for SVGs.

- Left/right: pause and scrub the timeline.
- Space: pause or resume the loop.

Shared controls:

- `Tab`: switch experiments.
- `R`: reset the active state.
- Escape: quit.
