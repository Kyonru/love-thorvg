# Asset browser

The basic example loads SVG and Lottie files through the same `love-thorvg`
API and presents them in a small asset browser.

Run it from this directory:

```sh
/Applications/love.app/Contents/MacOS/love .
```

- Arrow keys: browse assets.
- `R`: restart the active animation.
- Escape: quit.

`main.lua` only connects LÖVE callbacks. `browser.lua` owns loading, playback,
layout, and presentation; `catalog.lua` is the asset registry. See
[`assets/LICENSE.md`](assets/LICENSE.md) before redistributing the sample files.
