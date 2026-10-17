# LÖVE WebAssembly example

This experimental example is a real LÖVE game. `game/main.lua` runs through
LÖVE's normal callbacks, requires `love_thorvg`, reads two Lottie files from
LÖVE's virtual filesystem, and draws the resulting textures with
`love.graphics.draw`.

The custom compatibility runtime is built from pinned love.js, LÖVE, and
megasource revisions. It statically links ThorVG and preloads the browser Lua C
module, so the game uses the same compact Lua API as desktop builds.

Install Emscripten, Meson, Ninja, and CMake, then build from the repository root:

```sh
./scripts/build_web_example.sh
python3 -m http.server 8000 --directory dist/web-example
```

Open `http://localhost:8000`. The build writes generated JavaScript, WASM, and
game data under `dist/web-example`; those outputs are not committed.

The initial backend is intentionally single-threaded and disables audio. Web
support remains experimental while browser input, persistence, performance,
and compatibility receive broader testing.
