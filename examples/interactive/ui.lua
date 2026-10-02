local ui = {}

local function drawKey(theme, fonts, x, y, key, label, active)
  local keyWidth = math.max(34, fonts.key:getWidth(key) + 18)
  theme.setColor(active and theme.cobalt or theme.panelRaised)
  love.graphics.rectangle('fill', x, y, keyWidth, 28, 7, 7)
  theme.setColor(active and theme.ink or theme.muted)
  love.graphics.setFont(fonts.key)
  love.graphics.printf(key, x, y + 6, keyWidth, 'center')
  theme.setColor(theme.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.print(label, x + keyWidth + 12, y + 5)
end

function ui.drawVending(theme, fonts, vending, performance, rail, paused, compact)
  local x, y, width = rail.x, rail.y, rail.width
  theme.setColor(theme.ink)
  love.graphics.setFont(compact and fonts.compactTitle or fonts.title)
  love.graphics.printf('Pick a drink.', x, y, width, 'left')

  if compact then
    theme.setColor(theme.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('Hover or arrows to focus · Click or Enter to select · Tab switches',
      x, y + 44, width, 'left')
    love.graphics.printf(('%d FPS · %d draws · %.1f MB GPU · %.1f MB Lua'):format(
      performance.fps, performance.drawCalls, performance.textureMiB, performance.luaMiB),
      x, y + 68, width, 'left')
    return
  end

  theme.setColor(theme.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'Nine hover loops and nine purchase sequences live in one Lottie. LÖVE owns hit-testing and state; ThorVG draws the chosen segment.',
    x, y + 92, width, 'left')

  local statusY = y + 190
  theme.setColor(theme.line)
  love.graphics.line(x, statusY, x + width, statusY)
  theme.setColor(theme.cyan)
  love.graphics.setFont(fonts.label)
  local stateLabel = vending.state == 'selecting' and 'DISPENSING' or
    (vending.hoveredItem and 'READY TO SELECT' or 'WAITING FOR INPUT')
  love.graphics.print(stateLabel, x, statusY + 18)
  theme.setColor(theme.muted)
  love.graphics.print(vending.hoveredItem and
    ('ITEM  %02d / 09'):format(vending.hoveredItem) or 'ITEM  —', x, statusY + 43)
  love.graphics.print(('LOTTIE  %.0f KB · 18 MARKED STATES'):format(vending.assetKB),
    x, statusY + 65)

  local renderStats = vending.document:getRenderStats()
  local cacheStats = vending.document:getCacheStats()
  love.graphics.print(('%d FPS · %d DRAWS · %.1f MB GPU · %.1f MB LUA'):format(
    performance.fps, performance.drawCalls, performance.textureMiB, performance.luaMiB),
    x, statusY + 91)
  love.graphics.print(('RASTER %.1f MS · UPLOAD %.1f MS · %dx%d'):format(
    renderStats.lastRasterSeconds * 1000, renderStats.lastUploadSeconds * 1000,
    vending.document.width, vending.document.height), x, statusY + 113)
  love.graphics.print(('CACHE %d/%d · %d HITS · %d MISSES'):format(
    cacheStats.size, cacheStats.limit, cacheStats.hits, cacheStats.misses),
    x, statusY + 135)

  local controlsY = statusY + 176
  drawKey(theme, fonts, x, controlsY, 'MOUSE', 'Hover a drink')
  drawKey(theme, fonts, x, controlsY + 38, 'ARROWS', 'Move focus',
    vending.inputMode == 'keyboard')
  drawKey(theme, fonts, x, controlsY + 76, 'CLICK ENTER', 'Select drink',
    vending.state == 'selecting')
  drawKey(theme, fonts, x, controlsY + 114, 'SPACE',
    paused and 'Resume motion' or 'Pause motion', paused)
  drawKey(theme, fonts, x, controlsY + 152, 'TAB', 'Interactive map')
  drawKey(theme, fonts, x, controlsY + 190, 'R', 'Reset')
end

function ui.drawMap(theme, fonts, map, performance, rail, compact)
  local x, y, width = rail.x, rail.y, rail.width
  local active = map:activeRegion()
  local selected = map:selectedRegion()

  theme.setColor(theme.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print('SVG / HIT TEST 02', x, y)

  theme.setColor(theme.ink)
  love.graphics.setFont(fonts.compactTitle)
  love.graphics.printf(compact and 'Explore the Dominican Republic' or
    'Explore the\nDominican Republic', x, y + 30, width, 'left')

  if compact then
    theme.setColor(theme.cyan)
    love.graphics.setFont(fonts.label)
    love.graphics.printf(active.name .. ' · ' .. active.iso, x, y + 66, width, 'right')
    theme.setColor(theme.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('Hover and click · Arrows browse · Enter selects · Tab switches · R resets',
      x, y + 94, width, 'left')
    return
  end

  theme.setColor(theme.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'One SVG draws the map. A hidden color-coded render provides pixel-accurate province hit testing, including detached islands.',
    x, y + 112, width, 'left')

  local statusY = y + 212
  theme.setColor(theme.line)
  love.graphics.line(x, statusY, x + width, statusY)
  theme.setColor(theme.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print(active.name:upper(), x, statusY + 18)
  theme.setColor(theme.muted)
  love.graphics.print(('REGION  %02d / %02d · %s'):format(
    map:activeIndex(), #map.regions, active.iso), x, statusY + 43)
  love.graphics.print(('TYPE  %s · POSTAL  %s'):format(active.kind:upper(), active.postal),
    x, statusY + 65)
  love.graphics.print(selected and ('SELECTED  ' .. selected.name) or 'SELECTED  —',
    x, statusY + 87)
  love.graphics.print(('%d FPS · %d DRAWS · %.1f MB GPU · %.1f MB LUA'):format(
    performance.fps, performance.drawCalls, performance.textureMiB, performance.luaMiB),
    x, statusY + 113)
  love.graphics.print(('%d TARGETS · %d SVG PATHS · HIT MAP %dx%d'):format(
    #map.regions, map.pathCount, map.hitMap.width, map.hitMap.height), x, statusY + 135)

  local controlsY = statusY + 176
  drawKey(theme, fonts, x, controlsY, 'MOUSE', 'Hover a province')
  drawKey(theme, fonts, x, controlsY + 38, 'CLICK', 'Select province',
    map.inputMode == 'mouse' and map.selectedIndex ~= nil)
  drawKey(theme, fonts, x, controlsY + 76, 'ARROWS', 'Browse alphabetically',
    map.inputMode == 'keyboard')
  drawKey(theme, fonts, x, controlsY + 114, 'ENTER', 'Select focused province')
  drawKey(theme, fonts, x, controlsY + 152, 'TAB', 'SVG stencil')
  drawKey(theme, fonts, x, controlsY + 190, 'R', 'Reset selection')
end

function ui.drawStencil(theme, fonts, stencil, rail, paused, compact)
  local x, y, width = rail.x, rail.y, rail.width
  theme.setColor(theme.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print('SVG / STENCIL 03', x, y)

  theme.setColor(theme.ink)
  love.graphics.setFont(compact and fonts.compactTitle or fonts.title)
  love.graphics.printf(compact and 'Shape-driven rendering' or 'Shape-driven\nrendering',
    x, y + 30, width, 'left')

  if compact then
    theme.setColor(stencil.enabled and theme.cyan or theme.coral)
    love.graphics.setFont(fonts.label)
    love.graphics.printf(stencil.enabled and 'STENCIL ON' or 'STENCIL OFF',
      x, y + 34, width, 'right')
    theme.setColor(theme.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('LEFT/RIGHT rotate    UP/DOWN edge    S stencil    TAB switch    R reset',
      x, y + 72, width, 'left')
    return
  end

  theme.setColor(theme.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'The moving field is ordinary LÖVE drawing. The SVG writes the boundary into the stencil buffer.',
    x, y + 132, width, 'left')

  local statusY = y + 218
  theme.setColor(theme.line)
  love.graphics.line(x, statusY, x + width, statusY)
  theme.setColor(stencil.enabled and theme.cyan or theme.coral)
  love.graphics.setFont(fonts.label)
  love.graphics.print(stencil.enabled and 'STENCIL ON' or 'STENCIL OFF', x, statusY + 18)
  theme.setColor(theme.muted)
  love.graphics.print(('ANGLE  %+.0f°'):format(math.deg(stencil.rotation)), x, statusY + 43)
  love.graphics.print(('ALPHA CUTOFF  %.2f'):format(stencil.cutoff), x, statusY + 65)

  local controlsY = statusY + 108
  drawKey(theme, fonts, x, controlsY, 'LEFT RIGHT', 'Rotate SVG')
  drawKey(theme, fonts, x, controlsY + 38, 'UP DOWN', 'Adjust edge cutoff')
  drawKey(theme, fonts, x, controlsY + 76, 'S', 'Toggle stencil', stencil.enabled)
  drawKey(theme, fonts, x, controlsY + 114, 'SPACE',
    paused and 'Resume motion' or 'Pause motion', paused)
  drawKey(theme, fonts, x, controlsY + 152, 'R', 'Reset')
  drawKey(theme, fonts, x, controlsY + 190, 'TAB', 'Interactive vending')
end

return ui
