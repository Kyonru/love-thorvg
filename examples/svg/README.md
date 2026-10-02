# SVG stencil playground

This example uses the alpha channel of a ThorVG-rendered SVG to populate
LÖVE's stencil buffer. The animated field is made from ordinary
`love.graphics` calls and is only visible where the SVG is opaque.

Run it from this directory:

```sh
/Applications/love.app/Contents/MacOS/love .
```

Controls:

- Left/right: rotate the SVG mask.
- Up/down: adjust the alpha cutoff used by the stencil shader.
- `S`: enable or disable SVG clipping.
- Space: pause or resume the content animation.
- `R`: reset the playground.
- Escape: quit.

The stencil is binary, so the shader discards pixels below the selected alpha
cutoff. A future exploration can compare this with a Canvas-based alpha mask,
which preserves partially transparent antialiased edges.
