# Changelog

## v0.1.0 — 2026-10-16

The first release of `love-thorvg` adds native ThorVG rendering to LÖVE 11.x.

### Highlights

- Load SVG and Lottie documents through LÖVE's virtual filesystem.
- Render into reusable LÖVE textures with dirty-frame suppression and an
  optional bounded frame cache.
- Resolve relative Lottie images and explicitly mapped fonts.
- Control playback, seeking, sizing, texture filtering, and render statistics
  through a small Lua API.
- Ship tested native packages for macOS ARM64, macOS x64, Linux x64, and
  Windows x64.
- Include asset browsing, interactive vector graphics, and state-driven HUD
  examples, plus native API tests and a rendering benchmark.
