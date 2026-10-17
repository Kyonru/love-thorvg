<div class="lt-hero">
  <div class="lt-hero__copy">
    <p class="lt-kicker">LÖVE 11.x · SVG · Lottie · ThorVG</p>
    <h1>Vector artwork,<br><span>alive in LÖVE.</span></h1>
    <p class="lt-lede">Load SVG and Lottie through LÖVE's filesystem, render into reusable textures, and keep native details behind a compact Lua API.</p>
    <div class="lt-actions">
      <a class="md-button md-button--primary" href="getting-started/quick-start/">Render your first asset</a>
      <a class="md-button" href="API/">Read the API</a>
    </div>
  </div>
  <div class="lt-vector" aria-hidden="true">
    <svg viewBox="0 0 420 300" role="img">
      <path class="lt-vector__grid" d="M30 55H390M30 105H390M30 155H390M30 205H390M30 255H390M70 25V275M140 25V275M210 25V275M280 25V275M350 25V275" />
      <path class="lt-vector__ghost" d="M58 224C91 96 142 57 207 131C263 194 310 93 368 72" />
      <path class="lt-vector__live" d="M58 224C91 96 142 57 207 131C263 194 310 93 368 72" />
      <circle cx="58" cy="224" r="7" />
      <circle cx="207" cy="131" r="7" />
      <circle cx="368" cy="72" r="7" />
    </svg>
    <p><span>01</span> document → pixels → texture</p>
  </div>
</div>

## One document, one durable object

`love-thorvg` reads asset bytes through `love.filesystem`, gives them to
ThorVG's CPU renderer, and uploads the result into a reusable LÖVE texture.
Unchanged frames stay untouched; animation, seeking, or resizing marks the
document for another render.

<div class="lt-cards">
  <article class="lt-card">
    <p class="lt-card__label">Input</p>
    <h3>SVG and Lottie</h3>
    <p>Use vector artwork, animated JSON, relative PNG images, and explicitly mapped fonts.</p>
  </article>
  <article class="lt-card">
    <p class="lt-card__label">Runtime</p>
    <h3>Ordinary LÖVE textures</h3>
    <p>Draw, transform, clip, cache, or compose the rendered result with the rest of your scene.</p>
  </article>
  <article class="lt-card">
    <p class="lt-card__label">Distribution</p>
    <h3>No custom engine build</h3>
    <p>Copy the Lua module and the native library for your target platform into an existing game.</p>
  </article>
</div>

## The smallest useful example

```lua
local thorvg = require('love_thorvg')
local animation

function love.load()
  animation = thorvg.new('assets/animation.json', {
    width = 256,
    height = 256,
    autoplay = true,
    loop = true,
  })
end

function love.update(dt) animation:update(dt) end
function love.draw() animation:draw(100, 100) end
function love.quit() animation:release() end
```

The same constructor loads static SVG files. Continue with the
[quick start](getting-started/quick-start.md) to install a release and choose
render dimensions, or open the [complete Lua API](API.md).

## Know the rendering tradeoff

ThorVG rasterizes on the CPU and LÖVE uploads changed frames to the GPU. That
is a strong fit for UI illustrations, icons, loaders, maps, and a modest number
of animations. It is not intended to update hundreds of large documents every
frame. The [performance guide](reference/performance.md) explains sizing,
caching, and measurement.
