function love.load()
  local ok, err = pcall(function()
    local thorvg = require('love_thorvg')
    assert(thorvg.capabilities.svgFonts)
    require('elements')(thorvg)
    local svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><text x="8" y="90" font-family="TestFont" font-size="80" fill="#ffffff">AB</text></svg>'
    assert(love.filesystem.write('text.svg', svg))
    local config = {fonts = {TestFont = 'Abel-Regular.ttf'}}
    local first = thorvg.new('text.svg', config)
    local second = thorvg.new('text.svg', config)
    local function check(doc)
      local pixels = doc:getImageData()
      local visible = 0
      for y = 0, pixels:getHeight() - 1 do for x = 0, pixels:getWidth() - 1 do
        local _, _, _, alpha = pixels:getPixel(x, y)
        if alpha > 0 then visible = visible + 1 end
      end end
      assert(visible > 100, 'missing SVG text')
    end
    check(first)
    first:release()
    collectgarbage('collect')
    second:resize(256, 256)
    check(second)
    second:release()
    local success, message = pcall(thorvg.new, 'text.svg', {fonts = {TestFont = 'missing.ttf'}})
    assert(not success and tostring(message):find('font not found', 1, true))
    config.width = 0
    success, message = pcall(thorvg.new, 'text.svg', config)
    assert(not success and tostring(message):find('render dimensions', 1, true))
    -- A failed image allocation must not keep the previous font registration alive.
    config.width = 128
    local bytes = assert(love.filesystem.read('Abel-Regular.ttf'))
    config.assetResolver = function(source, kind)
      assert(source == 'name:TestFont' and kind == 'font')
      return bytes .. '\0'
    end
    local replacement = thorvg.new('text.svg', config)
    check(replacement)
    replacement:release()
    love.filesystem.remove('text.svg')
    print('PASS: LÖVE SVG font mapping, pixels, shared ownership, custom resolver and error cleanup')
  end)
  if not ok then print(err) end
  love.event.quit(ok and 0 or 1)
end
