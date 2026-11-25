# Changelog

## v0.3.0 — 2026-11-25

- Add desktop SVG element transforms, opacity, and parent-space bounds by ID.
- Update every matching instance, including named wrappers around SVG use instances, without reloading the document.
- Expose `capabilities.svgElements`, `Document:setElement`, and `Document:getElementBounds`.
- Invalidate cached frames after element edits while reusing the upload texture.

- Preload explicitly mapped SVG fonts on desktop before parsing documents.
- Expose `capabilities.svgFonts`, and report unsupported binaries or missing fonts.
- Share identical font data across live documents and reject conflicting family registrations.
- Add native text rendering, ownership, and failed-load cleanup tests.

## v0.2.0 — 2026-10-16

This release brings `love-thorvg` to the browser and makes installation and
evaluation easier across every supported desktop platform.

### Highlights

- Add an experimental Emscripten backend that runs through a custom LÖVE 11.4
  web runtime while preserving the compact Lua API.
- Add a real browser example that loads repository Lottie assets through
  `love.filesystem`, animates them with LÖVE callbacks, and renders them with
  ThorVG.
- Add automated WebAssembly, Lua bridge, browser animation, and asset-switching
  checks for the experimental backend.
- Publish a Zensical documentation site and the live web example through
  GitHub Pages, including setup and architecture guides for web support.
- Add a validated `all-desktop` release archive containing the macOS ARM64,
  macOS x64, Linux x64, and Windows x64 native libraries.
- Update GitHub Actions dependencies to their Node 24-compatible releases.

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
