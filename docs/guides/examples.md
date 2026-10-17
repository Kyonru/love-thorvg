# Examples

The repository includes standalone LÖVE projects that move from basic asset
loading to state-driven vector interfaces.

Clone the repository, then run an example from its root:

```sh
git clone https://github.com/Kyonru/love-thorvg.git
cd love-thorvg
love examples/asset-browser
```

## Asset browser

Start here to confirm that the module and native library load correctly. Use
the arrow keys to switch between SVG and Lottie assets, and press `R` to
restart the current animation.

```sh
love examples/asset-browser
```

## Interactive playground

This project combines ThorVG output with LÖVE interaction: SVG hit testing,
SVG-driven stencils, marker-aware Lottie playback, an interactive map, and a
vending-machine interface.

```sh
love examples/interactive
```

Press `Tab` to move between experiments. The map and vending machine support
both pointer and keyboard interaction.

## Living reliquary HUD

The HUD treats separate SVG documents as composable runtime layers. Shaders
recolor and reveal a branching health network, damage exposes cracks, and
ordinary LÖVE drawing adds phase rings, impact particles, and typography.

```sh
love examples/reliquary-hud
```

Use Left/Right to shape health, Space to strike, `H` to restore, `V` to toggle
blight, `P` to advance the phase, and `Q` to compare 1× and 2× rasterization.

Every example has an `assets/LICENSE.md` manifest. Check it before copying
sample artwork into another project.
