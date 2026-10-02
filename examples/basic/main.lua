package.path = '../../?.lua;../../?/init.lua;' .. package.path

local thorvg = require('love_thorvg')

local palette = {
  background = {0.953, 0.941, 0.914},
  ink = {0.075, 0.102, 0.145},
  muted = {0.075, 0.102, 0.145, 0.58},
  faint = {0.075, 0.102, 0.145, 0.14},
  error = {0.620, 0.153, 0.153},
}

local examples = {
  {name = 'Sample SVG', kind = 'SVG', path = 'assets/sample.svg'},
  {name = 'Relax', kind = 'LOTTIE', path = 'assets/Relax.json'},
}

local active
local activeIndex = 1
local loadError
local fonts = {}
local stage = {x = 0, y = 0, size = 1}

local function setColor(color)
  love.graphics.setColor(color)
end

local function targetSize()
  local width, height = love.graphics.getDimensions()
  return math.max(1, math.floor(math.min(width - 56, height - 184, 560)))
end

local function layout()
  local width, height = love.graphics.getDimensions()
  stage.size = targetSize()
  stage.x = math.floor((width - stage.size) * 0.5)
  stage.y = math.floor(72 + math.max(0, height - 184 - stage.size) * 0.38)
  if active then active:resize(stage.size, stage.size) end
end

local function openExample(index)
  index = ((index - 1) % #examples) + 1
  local item = examples[index]
  activeIndex = index
  local size = targetSize()
  local ok, result = pcall(thorvg.new, item.path, {
    width = size,
    height = size,
    autoplay = true,
    loop = true,
  })

  if not ok then
    loadError = tostring(result)
    print(loadError)
    return
  end

  if active then active:release() end
  active = result
  loadError = nil
  layout()
end

local function rotateExample(direction)
  openExample(activeIndex + direction)
end

local function restart()
  if not active then return end
  active:setProgress(0)
  active:play()
end

local function drawKeycap(label, x, y, width)
  love.graphics.setLineWidth(1)
  setColor(palette.faint)
  love.graphics.rectangle('line', x + 0.5, y + 0.5, width - 1, 26, 6, 6)
  setColor(palette.ink)
  love.graphics.setFont(fonts.key)
  love.graphics.printf(label, x, y + 7, width, 'center')
end

local function drawChrome()
  local width, height = love.graphics.getDimensions()
  local item = examples[activeIndex]

  love.graphics.setFont(fonts.brand)
  setColor(palette.ink)
  love.graphics.print('love-thorvg', 28, 24)

  love.graphics.setFont(fonts.meta)
  setColor(palette.muted)
  love.graphics.printf(('%02d / %02d'):format(activeIndex, #examples), 0, 27, width - 28, 'right')

  local footerY = height - 82
  setColor(palette.faint)
  love.graphics.rectangle('fill', 28, footerY - 17, width - 56, 1)

  love.graphics.setFont(fonts.title)
  setColor(loadError and palette.error or palette.ink)
  love.graphics.print(loadError and 'Unable to load example' or item.name, 28, footerY)

  love.graphics.setFont(fonts.meta)
  setColor(loadError and palette.error or palette.muted)
  local details
  if loadError then
    details = loadError:gsub('^.-:%d+: ', '')
  elseif active.duration > 0 then
    details = ('%s  ·  %.0f frames  ·  %.2fs'):format(item.kind, active.totalFrames, active.duration)
  else
    details = ('%s  ·  %d × %d'):format(item.kind, active.intrinsicWidth, active.intrinsicHeight)
  end
  love.graphics.print(details, 28, footerY + 27)

  local controlsX = width - 244
  drawKeycap('←', controlsX, footerY + 1, 30)
  drawKeycap('→', controlsX + 36, footerY + 1, 30)
  love.graphics.setFont(fonts.meta)
  setColor(palette.muted)
  love.graphics.print('Browse', controlsX + 74, footerY + 8)
  drawKeycap('R', controlsX + 142, footerY + 1, 30)
  love.graphics.setFont(fonts.meta)
  setColor(palette.muted)
  love.graphics.print('Restart', controlsX + 180, footerY + 8)
end

function love.load(args)
  love.graphics.setBackgroundColor(palette.background)
  fonts.brand = love.graphics.newFont(18)
  fonts.title = love.graphics.newFont(20)
  fonts.meta = love.graphics.newFont(12)
  fonts.key = love.graphics.newFont(11)
  local initialIndex = 1
  for _, argument in ipairs(args or {}) do
    if argument == 'lottie' then initialIndex = 2 end
  end
  openExample(initialIndex)
end

function love.resize()
  layout()
end

function love.update(dt)
  if active then active:update(dt) end
end

function love.keypressed(key)
  if key == 'left' or key == 'up' then
    rotateExample(-1)
  elseif key == 'right' or key == 'down' then
    rotateExample(1)
  elseif key == 'r' then
    restart()
  end
end

function love.draw()
  if active then active:draw(stage.x, stage.y) end
  drawChrome()
end

function love.quit()
  if active then active:release() end
  for _, font in pairs(fonts) do font:release() end
end
