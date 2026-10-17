# WebAssembly example

This experimental browser example decodes an SVG backdrop and two animations
shared with the repository's Lottie examples, then rasterizes them through the
real love-thorvg WebAssembly C ABI. Switch artwork, play, pause, restart, and
scrub the Lottie timeline from the browser UI.

Build the WebAssembly harness from the repository root:

```sh
meson setup build-web --cross-file web/emscripten.ini \
  -Dbuild_tests=false -Dweb_harness=true \
  -Dthorvg:threads=false -Dthorvg:simd=false -Dthorvg:file=false
meson compile -C build-web
```

Stage and serve the example:

```sh
cp build-web/love_thorvg_web.{js,wasm} examples/web/
python3 -m http.server 8000
```

Open `http://localhost:8000/examples/web/`. The generated JavaScript and WASM
files are ignored release output and should not be committed.
