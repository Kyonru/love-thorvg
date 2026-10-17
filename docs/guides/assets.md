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
