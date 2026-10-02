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
local morph
local rasterSnapshot
local stencilShader
local fonts = {}
local stage = {x = 0, y = 0, size = 1}
local rail = {x = 0, y = 0, width = 1}
local rotation = -0.12
local cutoff = 0.5
local elapsed = 0
local paused = false
local stencilEnabled = true
local experiment = 1
local morphProgress = 0
local morphManual = false
local morphSize = 1
local assetStats = {vectorKB = 0, pngKB = 0, spriteMiB = 0}

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

  if mask then mask:resize(stage.size, stage.size) end
  morphSize = math.max(96, math.floor(stage.size * (love.graphics.getWidth() < 820 and 0.42 or 0.46)))
  if morph then morph:resize(morphSize, morphSize) end
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

local function drawCheckerboard(x, y, size)
  local cell = math.max(12, math.floor(size / 8))
  love.graphics.setScissor(x, y, size, size)
  for row = 0, math.ceil(size / cell) do
    for column = 0, math.ceil(size / cell) do
      setColor((row + column) % 2 == 0 and colors.panelRaised or colors.panel, 0.72)
      love.graphics.rectangle('fill', x + column * cell, y + row * cell, cell, cell)
    end
  end
  love.graphics.setScissor()
end

local function drawComparisonLabel(text, x, y, width, active)
  setColor(active and colors.cyan or colors.coral)
  love.graphics.setFont(fonts.label)
  love.graphics.printf(text, x, y, width, 'center')
end

local function drawMorphStage()
  local x, y, size = stage.x, stage.y, stage.size
  setColor(colors.panel)
  love.graphics.rectangle('fill', x - 1, y - 1, size + 2, size + 2, 24, 24)

  local gutter = math.max(14, math.floor(size * 0.035))
  local paneWidth = (size - gutter * 3) * 0.5
  local visualSize = math.min(morphSize, paneWidth - 8)
  local visualY = y + math.max(54, size * 0.18)
  local leftX = x + gutter + (paneWidth - visualSize) * 0.5
  local rightPaneX = x + gutter * 2 + paneWidth
  local rightX = rightPaneX + (paneWidth - visualSize) * 0.5

  drawComparisonLabel('LAYERED VECTOR · LIVE', x + gutter, y + 24, paneWidth, true)
  drawComparisonLabel('PNG · ONE FRAME', rightPaneX, y + 24, paneWidth, false)
  drawCheckerboard(leftX, visualY, visualSize)
  drawCheckerboard(rightX, visualY, visualSize)

  love.graphics.setColor(1, 1, 1, 1)
  morph:setProgress(morphProgress)
  morph:draw(leftX + visualSize * 0.5, visualY + visualSize * 0.5, 0,
    visualSize / morphSize, visualSize / morphSize, morphSize * 0.5, morphSize * 0.5)

  love.graphics.setColor(1, 1, 1, 1)
  local rasterWidth, rasterHeight = rasterSnapshot:getDimensions()
  love.graphics.draw(rasterSnapshot, rightX + visualSize * 0.5, visualY + visualSize * 0.5,
    0, visualSize / rasterWidth, visualSize / rasterHeight, rasterWidth * 0.5, rasterHeight * 0.5)

  local captionY = visualY + visualSize + math.max(20, size * 0.055)
  setColor(colors.ink)
  love.graphics.setFont(fonts.body)
  love.graphics.printf('Bézier morph\n+ trim + tracks', x + gutter, captionY, paneWidth, 'center')
  love.graphics.printf('Fixed pixels\n+ one state', rightPaneX, captionY, paneWidth, 'center')

  setColor(colors.line)
  love.graphics.line(x + size * 0.5, y + 20, x + size * 0.5, y + size - 20)
  love.graphics.rectangle('line', x, y, size, size, 24, 24)
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

local function drawMorphRail(x, y, width, compact)
  setColor(colors.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print('VECTOR / RASTER 02', x, y)

  setColor(colors.ink)
  love.graphics.setFont(compact and fonts.compactTitle or fonts.title)
  love.graphics.printf(compact and 'One asset, coordinated motion' or 'One asset,\ncoordinated motion',
    x, y + 30, width, 'left')

  if compact then
    setColor(colors.muted)
    love.graphics.setFont(fonts.body)
    love.graphics.printf('LEFT/RIGHT scrub    SPACE pause    TAB switch    R reset',
      x, y + 72, width, 'left')
    return
  end

  setColor(colors.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(
    'For one polygon, use flux. ThorVG earns its place when a designer ships Bézier paths, trim animation, and layered tracks as one timeline.',
    x, y + 178, width, 'left')

  local statusY = y + 270
  setColor(colors.line)
  love.graphics.line(x, statusY, x + width, statusY)
  setColor(colors.cyan)
  love.graphics.setFont(fonts.label)
  love.graphics.print(('MORPH  %03d%%'):format(math.floor(morphProgress * 100 + 0.5)), x, statusY + 18)
  setColor(colors.muted)
  love.graphics.print(('VECTOR  %.1f KB'):format(assetStats.vectorKB), x, statusY + 43)
  love.graphics.print(('PNG SNAPSHOT  %.1f KB'):format(assetStats.pngKB), x, statusY + 65)
  love.graphics.printf(('3 layers · curved path · trim track. %d PNG frames at 256 px are about %.0f MiB decoded.'):format(
    morph.totalFrames, assetStats.spriteMiB), x, statusY + 91, width, 'left')

  local controlsY = statusY + 148
  drawKey(x, controlsY, 'LEFT RIGHT', 'Scrub morph')
  drawKey(x, controlsY + 38, 'SPACE', paused and 'Resume morph' or 'Pause morph', paused)
  drawKey(x, controlsY + 76, 'TAB', 'Stencil experiment')
  drawKey(x, controlsY + 114, 'R', 'Reset')
end

local function drawRail()
  local x, y, width = rail.x, rail.y, rail.width
  local compact = love.graphics.getWidth() < 820
  if experiment == 2 then
    drawMorphRail(x, y, width, compact)
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
  drawKey(x, controlsY + 190, 'TAB', 'Morph experiment')
end

local function reset()
  rotation = -0.12
  cutoff = 0.5
  elapsed = 0
  paused = false
  stencilEnabled = true
  morphProgress = 0
  morphManual = false
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
  morph = thorvg.new('assets/morph.json', {
    width = 256,
    height = 256,
    autoplay = false,
    filter = 'linear',
  })
  rasterSnapshot = love.graphics.newImage('assets/morph-start.png')
  rasterSnapshot:setFilter('linear', 'linear')
  local vectorInfo = love.filesystem.getInfo('assets/morph.json')
  local pngInfo = love.filesystem.getInfo('assets/morph-start.png')
  assetStats.vectorKB = vectorInfo.size / 1024
  assetStats.pngKB = pngInfo.size / 1024
  assetStats.spriteMiB = 256 * 256 * 4 * morph.totalFrames / (1024 * 1024)
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
    local scrubDirection = (love.keyboard.isDown('right') and 1 or 0) -
      (love.keyboard.isDown('left') and 1 or 0)
    if scrubDirection ~= 0 then
      paused = true
      morphManual = true
      morphProgress = math.max(0, math.min(1, morphProgress + scrubDirection * dt * 0.45))
    elseif not paused and not morphManual then
      morphProgress = 0.5 - 0.5 * math.cos(elapsed * 1.25)
    end
  end
end

function love.keypressed(key)
  if key == 's' then
    stencilEnabled = not stencilEnabled
  elseif key == 'space' then
    paused = not paused
    if not paused then morphManual = false end
  elseif key == 'r' then
    reset()
  elseif key == 'tab' then
    experiment = experiment == 1 and 2 or 1
    paused = false
    morphManual = false
  elseif key == 'escape' then
    love.event.quit()
  end
end

function love.draw()
  if experiment == 1 then drawStage() else drawMorphStage() end
  drawRail()
end

function love.quit()
  if mask then mask:release() end
  if morph then morph:release() end
  if rasterSnapshot then rasterSnapshot:release() end
end
