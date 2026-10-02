local thorvg = require('love_thorvg')
local catalog = require('catalog')

local Browser = {}
Browser.__index = Browser

local palette = {
  background = {0.953, 0.941, 0.914},
  ink = {0.075, 0.102, 0.145},
  muted = {0.075, 0.102, 0.145, 0.58},
  faint = {0.075, 0.102, 0.145, 0.14},
  error = {0.620, 0.153, 0.153},
}

local function targetSize()
  local width, height = love.graphics.getDimensions()
  return math.max(1, math.floor(math.min(width - 56, height - 184, 560)))
end

function Browser.new(args)
  local self = setmetatable({
    active = nil,
    activeIndex = 1,
    loadError = nil,
    stage = {x = 0, y = 0, size = 1},
    fonts = {
      brand = love.graphics.newFont(18),
      title = love.graphics.newFont(20),
      meta = love.graphics.newFont(12),
      key = love.graphics.newFont(11),
    },
  }, Browser)
  love.graphics.setBackgroundColor(palette.background)
  local initialIndex = 1
  for _, argument in ipairs(args or {}) do
    if argument == 'lottie' then initialIndex = 2 end
  end
  self:open(initialIndex)
  return self
end

function Browser:resize()
  local width, height = love.graphics.getDimensions()
  local stage = self.stage
  stage.size = targetSize()
  stage.x = math.floor((width - stage.size) * 0.5)
  stage.y = math.floor(72 + math.max(0, height - 184 - stage.size) * 0.38)
  if self.active then self.active:resize(stage.size, stage.size) end
end

function Browser:open(index)
  index = ((index - 1) % #catalog) + 1
  local item = catalog[index]
  local size = targetSize()
  local ok, result = pcall(thorvg.new, item.path, {
    width = size,
    height = size,
    autoplay = true,
    loop = true,
  })
  self.activeIndex = index
  if not ok then
    self.loadError = tostring(result)
    print(self.loadError)
    return
  end
  if self.active then self.active:release() end
  self.active = result
  self.loadError = nil
  self:resize()
end

function Browser:restart()
  if not self.active then return end
  self.active:setProgress(0)
  self.active:play()
end

function Browser:update(dt)
  if self.active then self.active:update(dt) end
end

function Browser:keypressed(key)
  if key == 'left' or key == 'up' then
    self:open(self.activeIndex - 1)
  elseif key == 'right' or key == 'down' then
    self:open(self.activeIndex + 1)
  elseif key == 'r' then
    self:restart()
  elseif key == 'escape' then
    love.event.quit()
  end
end

function Browser:drawKeycap(label, x, y, width)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(palette.faint)
  love.graphics.rectangle('line', x + 0.5, y + 0.5, width - 1, 26, 6, 6)
  love.graphics.setColor(palette.ink)
  love.graphics.setFont(self.fonts.key)
  love.graphics.printf(label, x, y + 7, width, 'center')
end

function Browser:drawChrome()
  local width, height = love.graphics.getDimensions()
  local item = catalog[self.activeIndex]
  local fonts = self.fonts
  love.graphics.setFont(fonts.brand)
  love.graphics.setColor(palette.ink)
  love.graphics.print('love-thorvg', 28, 24)
  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(palette.muted)
  love.graphics.printf(('%02d / %02d'):format(self.activeIndex, #catalog),
    0, 27, width - 28, 'right')

  local footerY = height - 82
  love.graphics.setColor(palette.faint)
  love.graphics.rectangle('fill', 28, footerY - 17, width - 56, 1)
  love.graphics.setFont(fonts.title)
  love.graphics.setColor(self.loadError and palette.error or palette.ink)
  love.graphics.print(self.loadError and 'Unable to load example' or item.name, 28, footerY)

  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(self.loadError and palette.error or palette.muted)
  local details
  if self.loadError then
    details = self.loadError:gsub('^.-:%d+: ', '')
  elseif self.active.duration > 0 then
    details = ('%s  ·  %.0f frames  ·  %.2fs'):format(
      item.kind, self.active.totalFrames, self.active.duration)
  else
    details = ('%s  ·  %d × %d'):format(
      item.kind, self.active.intrinsicWidth, self.active.intrinsicHeight)
  end
  love.graphics.print(details, 28, footerY + 27)

  local controlsX = width - 244
  self:drawKeycap('←', controlsX, footerY + 1, 30)
  self:drawKeycap('→', controlsX + 36, footerY + 1, 30)
  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(palette.muted)
  love.graphics.print('Browse', controlsX + 74, footerY + 8)
  self:drawKeycap('R', controlsX + 142, footerY + 1, 30)
  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(palette.muted)
  love.graphics.print('Restart', controlsX + 180, footerY + 8)
  love.graphics.setColor(1, 1, 1, 1)
end

function Browser:draw()
  if self.active then self.active:draw(self.stage.x, self.stage.y) end
  self:drawChrome()
end

function Browser:release()
  if self.active then self.active:release() end
  for _, font in pairs(self.fonts) do font:release() end
end

return Browser
