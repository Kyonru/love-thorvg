# Living reliquary HUD

A state-driven boss HUD built from layered SVG documents, shaders, and LÖVE
composition. The health value controls a branching sap network rather than a
rectangular crop. Damage progressively reveals cracks, a delayed damage layer
retreats through the same topology, and gameplay states recolor the network at
runtime.

Run from the repository root:

```sh
love examples/reliquary-hud
```

Controls:

- Left/Right: adjust health
- Space: strike
- H: restore health
- V: toggle blight
- P: advance the boss phase
- Q: switch between 1x and 2x runtime SVG rasterization
- R: restart

This is intentionally not a pre-rendered animation. The SVG frame, health
network, and crack topology are separately rasterized by ThorVG at the size
requested by the application. LÖVE then applies continuous health values,
delayed damage, state colors, phase rings, and impact effects without needing
a spritesheet for every combination.
