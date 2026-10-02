local Vending = {}
Vending.__index = Vending

local SOURCE_FPS = 60
local RENDER_FPS = 30
local RENDER_MAX_WIDTH = 480
local SOURCE_WIDTH = 1080
local SOURCE_HEIGHT = 810
local HOVER_STARTS = {15, 75, 135, 195, 255, 315, 375, 435, 495}
local CLICK_STARTS = {555, 675, 795, 913, 1031, 1147, 1251, 1370, 1485}
local CLICK_DURATIONS = {120, 121, 117, 117, 115, 103, 118, 114, 108}

function Vending.new(thorvg)
  local document = thorvg.new('assets/vending-machine.json', {
    width = 480,
    height = 360,
    autoplay = false,
    filter = 'linear',
    frameCache = 36,
  })
  local assetInfo = love.filesystem.getInfo('assets/vending-machine.json')
  return setmetatable({
    document = document,
    rect = {x = 0, y = 0, width = 1, height = 1},
    hoveredItem = nil,
    selectedItem = nil,
    state = 'idle',
    frame = 0,
    accumulator = 0,
    inputMode = 'mouse',
    assetKB = assetInfo.size / 1024,
    cursors = {
      arrow = love.mouse.getSystemCursor('arrow'),
      hand = love.mouse.getSystemCursor('hand'),
    },
  }, Vending)
end

function Vending:resize(stage)
  local rect = self.rect
  rect.width = stage.size
  rect.height = math.floor(stage.size * SOURCE_HEIGHT / SOURCE_WIDTH + 0.5)
  rect.x = stage.x
  rect.y = stage.y + math.floor((stage.size - rect.height) * 0.5)
  local renderWidth = math.min(rect.width, RENDER_MAX_WIDTH)
  self.document:resize(renderWidth,
    math.floor(renderWidth * SOURCE_HEIGHT / SOURCE_WIDTH + 0.5))
end

function Vending:itemAt(x, y)
  local rect = self.rect
  if x < rect.x or x >= rect.x + rect.width or
      y < rect.y or y >= rect.y + rect.height then
    return nil
  end

  local assetX = (x - rect.x) * SOURCE_WIDTH / rect.width
  local assetY = (y - rect.y) * SOURCE_HEIGHT / rect.height
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

function Vending:setHoveredItem(index, source)
  self.inputMode = source or self.inputMode
  if self.state == 'selecting' or self.hoveredItem == index then return end
  self.hoveredItem = index
  self.state = index and 'hovering' or 'idle'
  self.frame = index and HOVER_STARTS[index] or 0
  self.accumulator = 0
end

function Vending:activate(index)
  if not index then return false end
  self.hoveredItem = index
  self.selectedItem = index
  self.state = 'selecting'
  self.frame = CLICK_STARTS[index]
  self.accumulator = 0
  return true
end

function Vending:moveFocus(deltaColumn, deltaRow)
  local index = self.hoveredItem or self.selectedItem or 1
  local column = (index - 1) % 3
  local row = math.floor((index - 1) / 3)
  column = (column + deltaColumn) % 3
  row = (row + deltaRow) % 3
  self:setHoveredItem(row * 3 + column + 1, 'keyboard')
end

function Vending:update(dt, paused)
  if paused or self.state == 'idle' then return end
  self.accumulator = self.accumulator + dt
  if self.accumulator < 1 / RENDER_FPS then return end
  local steps = math.floor(self.accumulator * RENDER_FPS)
  self.accumulator = self.accumulator - steps / RENDER_FPS
  self.frame = self.frame + steps * SOURCE_FPS / RENDER_FPS

  if self.state == 'hovering' then
    local startFrame = HOVER_STARTS[self.hoveredItem]
    self.frame = startFrame + (self.frame - startFrame) % 60
  elseif self.state == 'selecting' then
    local endFrame = CLICK_STARTS[self.selectedItem] + CLICK_DURATIONS[self.selectedItem] - 1
    if self.frame >= endFrame then
      if self.inputMode == 'mouse' then
        self.hoveredItem = self:itemAt(love.mouse.getPosition())
      end
      self.state = self.hoveredItem and 'hovering' or 'idle'
      self.frame = self.hoveredItem and HOVER_STARTS[self.hoveredItem] or 0
    end
  end
end

function Vending:keypressed(key)
  if key == 'left' then
    self:moveFocus(-1, 0)
  elseif key == 'right' then
    self:moveFocus(1, 0)
  elseif key == 'up' then
    self:moveFocus(0, -1)
  elseif key == 'down' then
    self:moveFocus(0, 1)
  elseif key == 'return' or key == 'kpenter' then
    return self:activate(self.hoveredItem or self.selectedItem or 1)
  else
    return false
  end
  return true
end

function Vending:mousemoved(x, y)
  local item = self:itemAt(x, y)
  self:setHoveredItem(item, 'mouse')
  love.mouse.setCursor(item and self.cursors.hand or self.cursors.arrow)
end

function Vending:mousepressed(x, y, button)
  if button == 1 then return self:activate(self:itemAt(x, y)) end
  return false
end

function Vending:touchpressed(x, y)
  return self:activate(self:itemAt(x, y))
end

function Vending:draw(theme)
  local rect = self.rect
  local frame = math.floor(self.frame + 0.5)
  self.document:setProgress(frame / math.max(1, self.document.totalFrames - 1))
  love.graphics.setColor(1, 1, 1, 1)
  self.document:draw(rect.x, rect.y, 0,
    rect.width / self.document.width, rect.height / self.document.height)
  theme.setColor(theme.ink, 0.12)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', rect.x, rect.y, rect.width, rect.height, 18, 18)
end

function Vending:reset()
  self.hoveredItem = nil
  self.selectedItem = nil
  self.state = 'idle'
  self.frame = 0
  self.accumulator = 0
  self.inputMode = 'mouse'
end

function Vending:deactivate()
  love.mouse.setCursor(self.cursors.arrow)
end

function Vending:release()
  self.document:release()
end

return Vending
