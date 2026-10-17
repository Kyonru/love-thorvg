# Examples

## Asset browser

[`asset-browser/`](asset-browser/) is the quickest API tour. It loads several
SVG and Lottie files through the same document interface and supports browsing
and playback restart controls.

## Interactive vector lab

[`interactive/`](interactive/) demonstrates application-controlled behavior:
an SVG stencil, a pixel-precise interactive SVG map, and a marker-driven vending
machine with hover, keyboard focus, selection sequences, frame caching, and live
render statistics.

Each example is a standalone LÖVE project and includes an
`assets/LICENSE.md` manifest. Review that manifest before copying sample
artwork into another project.

## Living reliquary HUD

[`reliquary-hud/`](reliquary-hud/) is a high-detail, state-driven boss HUD.
Layered SVG documents provide an ornate frame, a branching health topology,
and progressive cracks; LÖVE shaders drive continuous health, delayed damage,
phase changes, runtime recoloring, and impact effects without enumerating every
state in a spritesheet.
