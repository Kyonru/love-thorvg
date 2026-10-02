local thorvg = require('love_thorvg')
local Map = require('experiments.map')
local Stencil = require('experiments.stencil')
local Vending = require('experiments.vending')
local theme = require('theme')
local ui = require('ui')

local App = {}
App.__index = App

function App.new()
  local fonts = {
    label = love.graphics.newFont(12),
    body = love.graphics.newFont(14),
    key = love.graphics.newFont(12),
    title = love.graphics.newFont(32),
    compactTitle = love.graphics.newFont(24),
    stage = love.graphics.newFont(44),
  }
  local self = setmetatable({
    fonts = fonts,
    stage = {x = 0, y = 0, size = 1},
    rail = {x = 0, y = 0, width = 1},
    map = Map.new(thorvg),
    stencil = Stencil.new(thorvg),
    vending = Vending.new(thorvg),
    experiment = 'vending',
    paused = false,
    elapsed = 0,
    performance = {fps = 0, drawCalls = 0, textureMiB = 0, luaMiB = 0},
  }, App)
  love.graphics.setBackgroundColor(theme.background)
  self:resize()
  return self
end

function App:resize()
  local width, height = love.graphics.getDimensions()
  local stage, rail = self.stage, self.rail
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
  self.stencil:resize(stage)
  self.vending:resize(stage)
  self.map:resize(stage)
end

function App:update(dt)
  if not self.paused then self.elapsed = self.elapsed + dt end
  if self.experiment == 'vending' then
    self.vending:update(dt, self.paused)
  elseif self.experiment == 'map' then
    self.map:update(dt, self.paused)
  elseif self.experiment == 'stencil' then
    self.stencil:update(dt, self.paused)
  end
end

function App:keypressed(key)
  if key == 'space' then
    self.paused = not self.paused
  elseif key == 'r' then
    self.elapsed = 0
    self.paused = false
    if self.experiment == 'vending' then
      self.vending:reset()
    elseif self.experiment == 'map' then
      self.map:reset()
    else
      self.stencil:reset()
    end
  elseif key == 'tab' then
    self.paused = false
    if self.experiment == 'vending' then
      self.experiment = 'map'
      self.vending:deactivate()
    elseif self.experiment == 'map' then
      self.experiment = 'stencil'
    else
      self.experiment = 'vending'
      self.vending:setHoveredItem(self.vending:itemAt(love.mouse.getPosition()), 'mouse')
    end
  elseif key == 'escape' then
    love.event.quit()
  elseif self.experiment == 'vending' then
    if self.vending:keypressed(key) then self.paused = false end
  elseif self.experiment == 'map' then
    if self.map:keypressed(key) then self.paused = false end
  else
    self.stencil:keypressed(key)
  end
end

function App:mousemoved(x, y)
  if self.experiment == 'vending' then
    self.vending:mousemoved(x, y)
  elseif self.experiment == 'map' then
    self.map:mousemoved(x, y)
  end
end

function App:mousepressed(x, y, button)
  if self.experiment == 'vending' and self.vending:mousepressed(x, y, button) then
    self.paused = false
  elseif self.experiment == 'map' and self.map:mousepressed(x, y, button) then
    self.paused = false
  end
end

function App:touchpressed(x, y)
  if self.experiment == 'vending' and self.vending:touchpressed(x, y) then
    self.paused = false
  elseif self.experiment == 'map' and self.map:touchpressed(x, y) then
    self.paused = false
  end
end

function App:draw()
  local compact = love.graphics.getWidth() < 820
  if self.experiment == 'vending' then
    self.vending:draw(theme)
    ui.drawVending(theme, self.fonts, self.vending, self.performance,
      self.rail, self.paused, compact)
  elseif self.experiment == 'map' then
    self.map:draw(self.stage, theme)
    ui.drawMap(theme, self.fonts, self.map, self.performance, self.rail, compact)
  else
    self.stencil:draw(self.stage, self.elapsed, self.fonts, theme)
    ui.drawStencil(theme, self.fonts, self.stencil, self.rail, self.paused, compact)
  end

  local stats = love.graphics.getStats()
  self.performance.fps = love.timer.getFPS()
  self.performance.drawCalls = stats.drawcalls
  self.performance.textureMiB = stats.texturememory / (1024 * 1024)
  self.performance.luaMiB = collectgarbage('count') / 1024
end

function App:release()
  self.map:release()
  self.stencil:release()
  self.vending:release()
  for _, font in pairs(self.fonts) do font:release() end
end

return App
