# Assets and fonts

`love-thorvg` reads the main document and its dependencies through LÖVE's
virtual filesystem. This keeps asset paths consistent in development and in a
`.love` archive.

## Relative images

Keep images beside the Lottie document using the paths recorded in its JSON:

```text
ui/
├── success.json
└── images/
    └── confetti.png
```

By default, `assetRoot` is the document's directory. Override it when several
documents share a common asset directory:

```lua
local success = thorvg.new('ui/success.json', {
  assetRoot = 'shared/lottie',
})
```

## Font mappings

Lottie may name a font family without storing a usable file path. Map that
family to a file in the virtual filesystem:

```lua
local title = thorvg.new('ui/title.json', {
  fonts = {
    Inter = 'fonts/Inter-Regular.ttf',
    ['Inter Display'] = 'fonts/InterDisplay-Bold.otf',
  },
})
```

Ship the font files and comply with their licenses just as you would for
images or animation artwork.

## SVG text (desktop)

SVG text also needs real font data. System names such as `system-ui` do not
load fonts from the operating system automatically. With an SVG-font-capable
native build, map the exact `font-family` used by the SVG:

```lua
local title = thorvg.new('ui/title.svg', {
  assetRoot = '', -- font path relative to the game root
  fonts = {Inter = 'fonts/Inter-Regular.ttf'},
})
assert(thorvg.capabilities.svgFonts)
```

Mapped fonts are loaded before SVG parsing. Missing or invalid supplied fonts
raise an error. Supply the actual face you want to render; automatic system-font
lookup, browser-style fallback lists and weight/style matching are not provided.

Fonts remain registered while any owning document is alive. Documents may share
a family when they supply identical bytes; a different font under the same live
family is rejected. Release all owners before replacing that family's data.
A custom resolver receives `name:<family>` with kind `font` for these mappings.

This is an additive native API; update both the Lua wrapper and native binary.
The v0.3.0 desktop binaries preload explicitly mapped SVG fonts. The experimental web backend does not.
`capabilities.svgFonts` lets integrations check support without guessing from the
version string. Existing Lottie mappings continue to work.

## Custom resolution

Use `assetResolver` when an asset comes from generated data, an alias table, or
another archive. Return a Lua string or LÖVE `Data` object, or `nil` to decline
the request.

```lua
local document = thorvg.new('ui/status.json', {
  assetResolver = function(source, kind)
    if kind == 'picture' and source == 'avatar.png' then
      return avatarFileData
    end
  end,
})
```

Resolver data is copied by the native layer before the callback returns. See
the [API reference](../API.md) for all related options.
