# GPU backend investigation

## Decision

Keep the CPU renderer as the production backend for LÖVE 11.x. ThorVG's
OpenGL backend is technically compatible with LÖVE's renderer, but LÖVE does
not expose the context and render-target handles needed for safe zero-copy
interop. ThorVG's WebGPU backend cannot share resources with LÖVE 11.x because
LÖVE does not use or expose a WebGPU device.

Do not add a LuaJIT FFI path that guesses LÖVE userdata layouts or reaches into
private C++ objects. It would be tied to a specific LÖVE build and could corrupt
graphics state or use released GPU objects.

## Feasibility

| Path | Copies | LÖVE 11.x viability | Main constraint |
| --- | ---: | --- | --- |
| CPU `SwCanvas` + `Image:replacePixels` | 1 CPU-to-GPU upload | Shipped | Upload bandwidth |
| ThorVG `GlCanvas` into a LÖVE `Canvas` | 0 | Blocked on public interop | No Lua API for the GL context or Canvas FBO |
| ThorVG `GlCanvas` into its own texture | 0 inside ThorVG | Not composable | LÖVE cannot import an external GL texture |
| ThorVG `GlCanvas` into the active framebuffer | 0 | Unsafe and feature-limited | LÖVE batching, hidden framebuffer choice, and GL state ownership |
| ThorVG `WgCanvas` into a WebGPU texture | 0 | Not applicable | No shared WebGPU device/texture in LÖVE 11.x |
| Separate WebGPU device plus readback/upload | 2+ | Possible but counterproductive | More synchronization and copies than the CPU path |

## OpenGL findings

The pinned ThorVG revision provides `GlCanvas::target(display, surface,
context, fbo, width, height, colorspace)`. It can render directly into an FBO
when the application's GL context is current. The target is restricted to its
supported RGBA colorspace, and the canvas must be synchronized before its
target changes. See the pinned
[ThorVG `GlCanvas` API](https://github.com/thorvg/thorvg/blob/fffc3f1af3b9854c8de647ac3b4d4c41fc21b62c/inc/thorvg.h#L2448-L2503).

LÖVE 11.5's OpenGL Canvas implementation has internal `getFBO()` and texture
handle methods, but they are private implementation interfaces rather than Lua
APIs. The official
[OpenGL Canvas header](https://github.com/love2d/love/blob/11.5/src/modules/graphics/opengl/Canvas.h)
contains the handles, while the public
[Texture Lua binding](https://github.com/love2d/love/blob/11.5/src/modules/graphics/wrap_Texture.cpp)
does not export them.

`love.graphics.flushBatch()` can submit pending LÖVE draws before an external
renderer runs, but it does not make LÖVE's cached GL state aware of changes made
by ThorVG. A correct bridge must also coordinate framebuffer binding, viewport,
scissor, blend mode, shaders, vertex state, active texture units, color space,
MSAA resolve, context loss, and object lifetime. Saving a guessed subset with
raw OpenGL calls is not a robust library boundary.

Rendering directly to the current framebuffer avoids importing a texture, but
it does not satisfy `ui.renderView`: the result cannot be freely transformed,
clipped, cached, or drawn later like a LÖVE texture. LÖVE may also be rendering
to an internal Canvas rather than framebuffer zero.

## WebGPU findings

The pinned ThorVG revision exposes `WgCanvas::target` for a `WGPUDevice`,
`WGPUInstance`, and a `WGPUSurface` or `WGPUTexture`; its context overload is
marked experimental. See the pinned
[ThorVG `WgCanvas` API](https://github.com/thorvg/thorvg/blob/fffc3f1af3b9854c8de647ac3b4d4c41fc21b62c/inc/thorvg.h#L2508-L2583).
Building it requires ThorVG's `wg` engine and `wgpu-native`, rather than the
current `engines=cpu` configuration.

LÖVE 11.5 uses its OpenGL graphics implementation and has no WebGPU device or
texture-sharing API. Creating an independent WebGPU device would not produce a
texture that `love.graphics.draw` can consume. Cross-API sharing through
Metal, Vulkan, Direct3D, or IOSurface-style platform handles would require a
different implementation per platform and explicit synchronization on both
sides.

## Recommended integration contract

GPU support becomes suitable for a distributable backend only if LÖVE exposes
a stable native interop contract with all of the following:

1. renderer identification and compatible native device/context handles;
2. a renderable LÖVE texture or Canvas handle with format, sample count, and
   lifetime guarantees;
3. begin/end external-render hooks that flush work and restore or invalidate
   LÖVE's graphics-state cache;
4. context-loss and target-recreation notifications;
5. a way to return the target as an ordinary drawable LÖVE texture.

Once that exists, keep the Lua API backend-neutral:

```lua
local animation = thorvg.new('animation.json', {
  backend = 'auto', -- cpu, opengl, or webgpu when available
  width = 256,
  height = 256,
})
```

Backend selection must fall back to CPU unless the requested backend is
explicitly required. `draw`, `getImage`, playback, caching, and resource
resolution should retain their existing behavior.

## Prototype gates

An OpenGL prototype should begin as an opt-in development build, not a release
artifact. It is ready to graduate only after it:

- renders into a LÖVE-owned Canvas through a supported handle API;
- survives Canvas recreation, window resize, fullscreen changes, and context
  loss on every supported platform;
- preserves LÖVE clipping, transforms, batching, gamma-correct rendering,
  premultiplied-alpha behavior, and MSAA;
- matches the CPU backend on the SVG/Lottie compatibility corpus;
- beats the measured CPU rasterization-plus-upload time at practical UI sizes;
- has no readback or hidden CPU upload in the steady-state frame path.

Until those gates are possible, the bounded frame cache and dirty-frame
suppression provide the safe optimization path without requiring a custom LÖVE
build.
