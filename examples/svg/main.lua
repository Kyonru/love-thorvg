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
local stencilShader
local fonts = {}
local stage = {x = 0, y = 0, size = 1}
local rail = {x = 0, y = 0, width = 1}
local rotation = -0.12
local cutoff = 0.5
local elapsed = 0
local paused = false
local stencilEnabled = true

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

local function drawRail()
  local x, y, width = rail.x, rail.y, rail.width
  local compact = love.graphics.getWidth() < 820
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
    love.graphics.printf('← → rotate    ↑ ↓ edge    S stencil    SPACE pause    R reset',
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
  drawKey(x, controlsY, '← →', 'Rotate SVG')
  drawKey(x, controlsY + 38, '↑ ↓', 'Adjust edge cutoff')
  drawKey(x, controlsY + 76, 'S', 'Toggle stencil', stencilEnabled)
  drawKey(x, controlsY + 114, 'SPACE', paused and 'Resume motion' or 'Pause motion', paused)
  drawKey(x, controlsY + 152, 'R', 'Reset')
end

local function reset()
  rotation = -0.12
  cutoff = 0.5
  elapsed = 0
  paused = false
  stencilEnabled = true
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
  layout()
end

function love.resize()
  layout()
end

function love.update(dt)
  if not paused then elapsed = elapsed + dt end
  local rotationSpeed = 1.15
  if love.keyboard.isDown('left') then rotation = rotation - rotationSpeed * dt end
  if love.keyboard.isDown('right') then rotation = rotation + rotationSpeed * dt end
  if love.keyboard.isDown('up') then cutoff = math.min(0.95, cutoff + dt * 0.5) end
  if love.keyboard.isDown('down') then cutoff = math.max(0.05, cutoff - dt * 0.5) end
end

function love.keypressed(key)
  if key == 's' then
    stencilEnabled = not stencilEnabled
  elseif key == 'space' then
    paused = not paused
  elseif key == 'r' then
    reset()
  elseif key == 'escape' then
    love.event.quit()
  end
end

function love.draw()
  drawStage()
  drawRail()
end

function love.quit()
  if mask then mask:release() end
end
