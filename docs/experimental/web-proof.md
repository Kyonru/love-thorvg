# Web proof

The [live LÖVE example](/love-thorvg/experimental/web-demo/) boots a custom LÖVE
runtime in the browser and executes `examples/web/game/main.lua`. That Lua game
requires `love_thorvg`, loads Lottie artwork shared with the native examples,
updates it in `love.update`, and draws its texture in `love.draw`.

[Run the web example](/love-thorvg/experimental/web-demo/){ .md-button .md-button--primary }

## Automated evidence

Every web-backend and documentation build runs `tests/web_wasm_test.mjs`. The
low-level test:

1. instantiates the Emscripten module in Node;
2. checks ABI version 2;
3. loads an SVG from bytes, renders an 8×8 RGBA target, and checks that the
   center pixel is opaque red;
4. loads a Lottie document, checks its timeline metadata, renders progress
   `0.5`, and checks for non-transparent output;
5. prints stable SHA-256 prefixes for both RGBA buffers.

A successful run ends with:

```text
PASS: ThorVG decoded and rasterized SVG and Lottie inside WebAssembly.
```

The GitHub Actions run also uploads the HTML, JavaScript, and WASM files as an
`experimental-web-proof` artifact.

The web workflow additionally runs `tests/web_love_test.mjs` in headless
Chromium. That browser test:

1. boots the custom compatibility build and waits for a marker printed by Lua;
2. verifies LÖVE reports `OS=Web` and love-thorvg reports ABI 2;
3. captures two canvas frames and confirms the Lottie animation changes;
4. sends an Arrow Right key event to the focused LÖVE canvas;
5. waits for Lua to open the Thanksgiving Turkey asset; and
6. fails on any page or console error.

A successful browser run ends with:

```text
PASS: LÖVE ran Lua callbacks and animated ThorVG Lottie textures in Chromium.
```

## What this proves

Together, the tests prove that the pinned sources compile for `wasm32`, the C
ABI decodes SVG and Lottie, the custom runtime starts LÖVE with PUC Lua 5.1, the
automatic Web backend loads, LÖVE filesystem reads work, ThorVG frames become
LÖVE textures, animation advances, and browser input reaches Lua.

This is still not a claim of full LÖVE-on-Web compatibility. The proof build is
single-threaded and deliberately excludes audio and several unused modules.
Web support remains experimental while those boundaries and more browsers are
tested.
