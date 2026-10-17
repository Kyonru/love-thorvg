# Web proof

The [live WebAssembly example](/love-thorvg/experimental/web-demo/) loads the
generated module in the browser, decodes an SVG instrument face, and animates a
Lottie orbit by rasterizing every frame with ThorVG. Its status line reports
the live C ABI version and document details; playback and scrubbing are interactive.

[Run the web example](/love-thorvg/experimental/web-demo/){ .md-button .md-button--primary }

<video controls muted loop playsinline preload="metadata" style="width: 100%;" aria-label="Recording of the love-thorvg WebAssembly example rendering and scrubbing a Lottie animation">
  <source src="/love-thorvg/assets/web-example.mp4" type="video/mp4">
  Your browser does not support embedded video. <a href="/love-thorvg/assets/web-example.mp4">Download the recording</a>.
</video>

## Automated evidence

Every web-backend and documentation build runs
`tests/web_wasm_test.mjs`. The test:

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
`experimental-web-proof` artifact. The Pages workflow runs the same assertions
before it is allowed to publish the live demo.

## What this proves

It proves that the pinned ThorVG source and love-thorvg C ABI compile for
`wasm32`, initialize, decode both supported formats, expose correct metadata,
and produce RGBA pixels in WebAssembly memory.

It does not yet prove every part of a custom love.js runtime. The Lua binding
sources and automatic backend selection are present, but the project does not
publish a patched love.js binary. Until that full runner is built and exercised
in a browser, web support remains explicitly experimental.
