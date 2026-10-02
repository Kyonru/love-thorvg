package.path = '../../?.lua;../../?/init.lua;' .. package.path

local thorvg = require('love_thorvg')

local colors = {
  background = {0.035, 0.047, 0.098},
  panel = {0.065, 0.082, 0.155},
  panelRaised = {0.086, 0.106, 0.196},
  ink = {0.895, 0.925, 1.000},
  muted = {0.565, 0.620, 0.765},
  line = {0.190, 0.225, 0.380},
  cobalt = {0.310, 0.380, 1.000},
  coral = {1.000, 0.430, 0.350},
  cyan = {0.230, 0.850, 0.920},
  yellow = {1.000, 0.800, 0.260},
}

local mask
local vending
local stencilShader
local fonts = {}
local stage = {x = 0, y = 0, size = 1}
local vendingRect = {x = 0, y = 0, width = 1, height = 1}
local rail = {x = 0, y = 0, width = 1}
local rotation = -0.12
local cutoff = 0.5
local elapsed = 0
local paused = false
local stencilEnabled = true
local experiment = 2
local hoveredItem
local selectedItem
local vendingState = 'idle'
local vendingFrame = 0
local vendingAccumulator = 0
local inputMode = 'mouse'
local cursors = {}
local assetStats = {vectorKB = 0}
local performance = {
  fps = 0,
  drawCalls = 0,
  textureMiB = 0,
  luaMiB = 0,
}

local VENDING_FPS = 60
local VENDING_RENDER_FPS = 30
local VENDING_RENDER_MAX_WIDTH = 480
local VENDING_WIDTH = 1080
local VENDING_HEIGHT = 810
local HOVER_STARTS = {15, 75, 135, 195, 255, 315, 375, 435, 495}
local CLICK_STARTS = {555, 675, 795, 913, 1031, 1147, 1251, 1370, 1485}
local CLICK_DURATIONS = {120, 121, 117, 117, 115, 103, 118, 114, 108}

local function setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function layout()
  local width, height = love.graphics.getDimensions()
  if width >= 820 then
    stage.size = math.max(320, math.min(height - 80, width - 390))
    stage.x = 40
    stage.y = math.floor((height - stage.size) * 0.5)
    rail.x = stage.x + stage.size + 44
    rail.y = stage.y + 18
    rail.width = width - rail.x - 40
  else
    stage.size = math.max(280, math.min(width - 40, height - 210))
    stage.x = math.floor((width - stage.size) * 0.5)
    stage.y = 24
    rail.x = 28
    rail.y = stage.y + stage.size + 28
    rail.width = width - 56
  end

  vendingRect.width = stage.size
  vendingRect.height = math.floor(stage.size * VENDING_HEIGHT / VENDING_WIDTH + 0.5)
  vendingRect.x = stage.x
  vendingRect.y = stage.y + math.floor((stage.size - vendingRect.height) * 0.5)

  if mask then mask:resize(stage.size, stage.size) end
  if vending then
    local renderWidth = math.min(vendingRect.width, VENDING_RENDER_MAX_WIDTH)
    vending:resize(renderWidth, math.floor(renderWidth * VENDING_HEIGHT / VENDING_WIDTH + 0.5))
  end
end

local function drawMask()
  local centerX = stage.x + stage.size * 0.5
  local centerY = stage.y + stage.size * 0.5
  love.graphics.draw(mask:getImage(), centerX, centerY, rotation, 1, 1,
    stage.size * 0.5, stage.size * 0.5)
end

local function drawMovingField()
  local x, y, size = stage.x, stage.y, stage.size
  setColor(colors.cobalt)
  love.graphics.rectangle('fill', x - size * 0.2, y - size * 0.2, size * 1.4, size * 1.4)

  local drift = (elapsed * 74) % (size * 0.5)
  love.graphics.push()
  love.graphics.translate(x + size * 0.5, y + size * 0.5)
  love.graphics.rotate(-0.42)
  for index = -5, 5 do
    local bandX = index * size * 0.22 + drift - size * 0.25
    setColor(index % 2 == 0 and colors.coral or colors.yellow, 0.92)
    love.graphics.rectangle('fill', bandX, -size, size * 0.105, size * 2)
  end
  love.graphics.pop()

  setColor(colors.cyan, 0.88)
  love.graphics.circle('fill', x + size * (0.25 + 0.08 * math.sin(elapsed * 0.9)),
    y + size * (0.30 + 0.06 * math.cos(elapsed * 1.1)), size * 0.14)
  setColor(colors.background, 0.75)
  love.graphics.circle('fill', x + size * (0.73 + 0.05 * math.cos(elapsed * 0.7)),
    y + size * (0.72 + 0.08 * math.sin(elapsed)), size * 0.18)

  setColor(colors.ink, 0.95)
  love.graphics.setFont(fonts.stage)
  love.graphics.printf('DRAW\nINSIDE', x + size * 0.13, y + size * 0.38,
    size * 0.74, 'center')
end

local function drawStage()
  setColor(colors.panel)
  love.graphics.rectangle('fill', stage.x - 1, stage.y - 1, stage.size + 2, stage.size + 2, 24, 24)

  if stencilEnabled then
    stencilShader:send('cutoff', cutoff)
    love.graphics.stencil(function()
      love.graphics.setShader(stencilShader)
      drawMask()
      love.graphics.setShader()
    end, 'replace', 1)
    love.graphics.setStencilTest('equal', 1)
    drawMovingField()
    love.graphics.setStencilTest()
  else
    love.graphics.setScissor(stage.x, stage.y, stage.size, stage.size)
    drawMovingField()
    love.graphics.setScissor()
    setColor(colors.ink, 0.13)
    drawMask()
  end

  setColor(colors.ink, 0.10)
  drawMask()
  setColor(colors.line, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', stage.x, stage.y, stage.size, stage.size, 24, 24)
end

local function drawVendingStage()
  love.graphics.setColor(1, 1, 1, 1)
  local frame = math.floor(vendingFrame + 0.5)
  vending:setProgress(frame / math.max(1, vending.totalFrames - 1))
  vending:draw(vendingRect.x, vendingRect.y, 0,
    vendingRect.width / vending.width, vendingRect.height / vending.height)

  setColor(colors.ink, 0.12)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', vendingRect.x, vendingRect.y,
    vendingRect.width, vendingRect.height, 18, 18)
end

local function itemAt(x, y)
  if x < vendingRect.x or x >= vendingRect.x + vendingRect.width or
      y < vendingRect.y or y >= vendingRect.y + vendingRect.height then
    return nil
  end

  local assetX = (x - vendingRect.x) * VENDING_WIDTH / vendingRect.width
  local assetY = (y - vendingRect.y) * VENDING_HEIGHT / vendingRect.height
  local gridX, gridY = 168, 170
  local cellWidth, cellHeight = 182, 180
  if assetX < gridX or assetX >= gridX + cellWidth * 3 or
      assetY < gridY or assetY >= gridY + cellHeight * 3 then
    return nil
  end

  local column = math.floor((assetX - gridX) / cellWidth)
  local row = math.floor((assetY - gridY) / cellHeight)
  return row * 3 + column + 1
end

local function setHoveredItem(index, source)
  inputMode = source or inputMode
  if vendingState == 'selecting' or hoveredItem == index then return end
  hoveredItem = index
  vendingState = index and 'hovering' or 'idle'
  vendingFrame = index and HOVER_STARTS[index] or 0
  vendingAccumulator = 0
end

local function activateItem(index)
  if not index then return end
  hoveredItem = index
  selectedItem = index
  vendingState = 'selecting'
  vendingFrame = CLICK_STARTS[index]
  vendingAccumulator = 0
  paused = false
end

local function moveFocus(deltaColumn, deltaRow)
  local index = hoveredItem or selectedItem or 1
  local column = (index - 1) % 3
  local row = math.floor((index - 1) / 3)
  column = (column + deltaColumn) % 3
  row = (row + deltaRow) % 3
  setHoveredItem(row * 3 + column + 1, 'keyboard')
end

local function drawKey(x, y, key, label, active)
  local keyWidth = math.max(34, fonts.key:getWidth(key) + 18)
  setColor(active and colors.cobalt or colors.panelRaised)
  love.graphics.rectangle('fill', x, y, keyWidth, 28, 7, 7)
  setColor(active and colors.ink or colors.muted)
  love.graphics.setFont(fonts.key)
  love.graphics.printf(key, x, y + 6, keyWidth, 'center')
  setColor(colors.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.print(label, x + keyWidth + 12, y + 5)
end

local function drawVendingRail(x, y, width, compact)
  setColor(colors.ink)
  love.graphics.setFont(compact and fonts.compactTitle or fonts.title)
  love.graphics.printf('Pick a drink.', x, y, width, 'left')

  if compact then
    setColor(colors.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('Hover or arrows to focus · Click or Enter to select · Tab switches',
      x, y + 44, width, 'left')
    love.graphics.printf(('%d FPS · %d draws · %.1f MB GPU · %.1f MB Lua'):format(
      performance.fps, performance.drawCalls, performance.textureMiB, performance.luaMiB),
      x, y + 68, width, 'left')
    return
  end

  setColor(colors.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'Nine hover loops and nine purchase sequences live in one Lottie. LÖVE owns hit-testing and state; ThorVG draws the chosen segment.',
    x, y + 92, width, 'left')

  local statusY = y + 190
  setColor(colors.line)
  love.graphics.line(x, statusY, x + width, statusY)
  setColor(colors.cyan)
  love.graphics.setFont(fonts.label)
  local stateLabel = vendingState == 'selecting' and 'DISPENSING' or
    (hoveredItem and 'READY TO SELECT' or 'WAITING FOR INPUT')
  love.graphics.print(stateLabel, x, statusY + 18)
  setColor(colors.muted)
  love.graphics.print(hoveredItem and ('ITEM  %02d / 09'):format(hoveredItem) or 'ITEM  —',
    x, statusY + 43)
  love.graphics.print(('LOTTIE  %.0f KB · %d MARKED STATES'):format(assetStats.vectorKB, 18),
    x, statusY + 65)

  local renderStats = vending:getRenderStats()
  local cacheStats = vending:getCacheStats()
  love.graphics.print(('%d FPS · %d DRAWS · %.1f MB GPU · %.1f MB LUA'):format(
    performance.fps, performance.drawCalls, performance.textureMiB, performance.luaMiB),
    x, statusY + 91)
  love.graphics.print(('RASTER %.1f MS · UPLOAD %.1f MS · %dx%d'):format(
    renderStats.lastRasterSeconds * 1000, renderStats.lastUploadSeconds * 1000,
    vending.width, vending.height), x, statusY + 113)
  love.graphics.print(('CACHE %d/%d · %d HITS · %d MISSES'):format(
    cacheStats.size, cacheStats.limit, cacheStats.hits, cacheStats.misses),
    x, statusY + 135)

  local controlsY = statusY + 176
  drawKey(x, controlsY, 'MOUSE', 'Hover a drink')
  drawKey(x, controlsY + 38, 'ARROWS', 'Move focus', inputMode == 'keyboard')
  drawKey(x, controlsY + 76, 'CLICK ENTER', 'Select drink', vendingState == 'selecting')
  drawKey(x, controlsY + 114, 'SPACE', paused and 'Resume motion' or 'Pause motion', paused)
  drawKey(x, controlsY + 152, 'TAB', 'Stencil experiment')
  drawKey(x, controlsY + 190, 'R', 'Reset')
end

local function drawRail()
  local x, y, width = rail.x, rail.y, rail.width
  local compact = love.graphics.getWidth() < 820
  if experiment == 2 then
    drawVendingRail(x, y, width, compact)
    return
  end
  setColor(colors.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print('SVG / STENCIL 01', x, y)

  setColor(colors.ink)
  love.graphics.setFont(compact and fonts.compactTitle or fonts.title)
  love.graphics.printf(compact and 'Shape-driven rendering' or 'Shape-driven\nrendering',
    x, y + 30, width, 'left')

  if compact then
    setColor(stencilEnabled and colors.cyan or colors.coral)
    love.graphics.setFont(fonts.label)
    love.graphics.printf(stencilEnabled and 'STENCIL ON' or 'STENCIL OFF',
      x, y + 34, width, 'right')
    setColor(colors.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('LEFT/RIGHT rotate    UP/DOWN edge    S stencil    TAB switch    R reset',
      x, y + 72, width, 'left')
    return
  end

  setColor(colors.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'The moving field is ordinary LÖVE drawing. The SVG writes the boundary into the stencil buffer.',
    x, y + 132, width, 'left')

  local statusY = y + 218
  setColor(colors.line)
  love.graphics.line(x, statusY, x + width, statusY)
  setColor(stencilEnabled and colors.cyan or colors.coral)
  love.graphics.setFont(fonts.label)
  love.graphics.print(stencilEnabled and 'STENCIL ON' or 'STENCIL OFF', x, statusY + 18)
  setColor(colors.muted)
  love.graphics.print(('ANGLE  %+.0f°'):format(math.deg(rotation)), x, statusY + 43)
  love.graphics.print(('ALPHA CUTOFF  %.2f'):format(cutoff), x, statusY + 65)

  local controlsY = statusY + 108
  drawKey(x, controlsY, 'LEFT RIGHT', 'Rotate SVG')
  drawKey(x, controlsY + 38, 'UP DOWN', 'Adjust edge cutoff')
  drawKey(x, controlsY + 76, 'S', 'Toggle stencil', stencilEnabled)
  drawKey(x, controlsY + 114, 'SPACE', paused and 'Resume motion' or 'Pause motion', paused)
  drawKey(x, controlsY + 152, 'R', 'Reset')
  drawKey(x, controlsY + 190, 'TAB', 'Interactive vending')
end

local function reset()
  rotation = -0.12
  cutoff = 0.5
  elapsed = 0
  paused = false
  stencilEnabled = true
  hoveredItem = nil
  selectedItem = nil
  vendingState = 'idle'
  vendingFrame = 0
  vendingAccumulator = 0
  inputMode = 'mouse'
end

function love.load()
  love.graphics.setBackgroundColor(colors.background)
  fonts.label = love.graphics.newFont(12)
  fonts.body = love.graphics.newFont(14)
  fonts.key = love.graphics.newFont(12)
  fonts.title = love.graphics.newFont(32)
  fonts.compactTitle = love.graphics.newFont(24)
  fonts.stage = love.graphics.newFont(44)

  stencilShader = love.graphics.newShader([[
    extern number cutoff;

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
    {
      vec4 pixel = Texel(texture, texture_coords);
      if (pixel.a < cutoff) discard;
      return pixel * color;
    }
  ]])

  mask = thorvg.new('assets/mask.svg', {
    width = 600,
    height = 600,
    autoplay = false,
    filter = 'linear',
  })
  vending = thorvg.new('assets/vending-machine.json', {
    width = 540,
    height = 405,
    autoplay = false,
    filter = 'linear',
    frameCache = 36,
  })
  local vectorInfo = love.filesystem.getInfo('assets/vending-machine.json')
  assetStats.vectorKB = vectorInfo.size / 1024
  cursors.arrow = love.mouse.getSystemCursor('arrow')
  cursors.hand = love.mouse.getSystemCursor('hand')
  layout()
end

function love.resize()
  layout()
end

function love.update(dt)
  if not paused then elapsed = elapsed + dt end
  if experiment == 1 then
    local rotationSpeed = 1.15
    if love.keyboard.isDown('left') then rotation = rotation - rotationSpeed * dt end
    if love.keyboard.isDown('right') then rotation = rotation + rotationSpeed * dt end
    if love.keyboard.isDown('up') then cutoff = math.min(0.95, cutoff + dt * 0.5) end
    if love.keyboard.isDown('down') then cutoff = math.max(0.05, cutoff - dt * 0.5) end
  else
    if paused or vendingState == 'idle' then return end
    vendingAccumulator = vendingAccumulator + dt
    if vendingAccumulator < 1 / VENDING_RENDER_FPS then return end
    local steps = math.floor(vendingAccumulator * VENDING_RENDER_FPS)
    vendingAccumulator = vendingAccumulator - steps / VENDING_RENDER_FPS
    vendingFrame = vendingFrame + steps * VENDING_FPS / VENDING_RENDER_FPS

    if vendingState == 'hovering' then
      local startFrame = HOVER_STARTS[hoveredItem]
      vendingFrame = startFrame + (vendingFrame - startFrame) % 60
    elseif vendingState == 'selecting' then
      local endFrame = CLICK_STARTS[selectedItem] + CLICK_DURATIONS[selectedItem] - 1
      if vendingFrame >= endFrame then
        if inputMode == 'mouse' then
          hoveredItem = itemAt(love.mouse.getPosition())
        end
        vendingState = hoveredItem and 'hovering' or 'idle'
        vendingFrame = hoveredItem and HOVER_STARTS[hoveredItem] or 0
      end
    end
  end
end

function love.keypressed(key)
  if key == 's' then
    stencilEnabled = not stencilEnabled
  elseif key == 'space' then
    paused = not paused
  elseif key == 'r' then
    reset()
  elseif key == 'tab' then
    experiment = experiment == 1 and 2 or 1
    paused = false
    if experiment == 2 then
      setHoveredItem(itemAt(love.mouse.getPosition()), 'mouse')
    else
      love.mouse.setCursor(cursors.arrow)
    end
  elseif experiment == 2 and key == 'left' then
    moveFocus(-1, 0)
  elseif experiment == 2 and key == 'right' then
    moveFocus(1, 0)
  elseif experiment == 2 and key == 'up' then
    moveFocus(0, -1)
  elseif experiment == 2 and key == 'down' then
    moveFocus(0, 1)
  elseif experiment == 2 and (key == 'return' or key == 'kpenter') then
    activateItem(hoveredItem or selectedItem or 1)
  elseif key == 'escape' then
    love.event.quit()
  end
end

function love.mousemoved(x, y)
  if experiment ~= 2 then return end
  local item = itemAt(x, y)
  setHoveredItem(item, 'mouse')
  love.mouse.setCursor(item and cursors.hand or cursors.arrow)
end

function love.mousepressed(x, y, button)
  if experiment == 2 and button == 1 then activateItem(itemAt(x, y)) end
end

function love.touchpressed(_, x, y)
  if experiment == 2 then activateItem(itemAt(x, y)) end
end

function love.draw()
  if experiment == 1 then drawStage() else drawVendingStage() end
  drawRail()

  local graphicsStats = love.graphics.getStats()
  performance.fps = love.timer.getFPS()
  performance.drawCalls = graphicsStats.drawcalls
  performance.textureMiB = graphicsStats.texturememory / (1024 * 1024)
  performance.luaMiB = collectgarbage('count') / 1024
end

function love.quit()
  if mask then mask:release() end
  if vending then vending:release() end
end
