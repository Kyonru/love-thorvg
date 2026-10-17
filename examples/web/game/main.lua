package.path = './?.lua;./?/init.lua;' .. package.path

local thorvg = require('love_thorvg')

local assets = {
  {name = 'Relax', file = 'assets/relax.json'},
  {name = 'Thanksgiving Turkey', file = 'assets/turkey.json'},
}

local palette = {
  background = {0.039, 0.075, 0.114},
  surface = {0.051, 0.098, 0.137},
  stage = {0.82, 0.875, 0.875},
  rule = {0.169, 0.263, 0.322},
  paper = {0.906, 0.941, 0.941},
  muted = {0.596, 0.686, 0.710},
  mint = {0.561, 0.827, 0.780},
  coral = {0.941, 0.471, 0.404},
  overlay = {0.039, 0.075, 0.114, 0.9},
}

local active
local activeIndex = 1
local loadError
local fonts = {}
local stage = {x = 80, y = 88, size = 560}
local controls = {
  previous = {x = 80, y = 652, width = 116, height = 42},
  play = {x = 210, y = 652, width = 116, height = 42},
  restart = {x = 340, y = 652, width = 116, height = 42},
  next = {x = 470, y = 652, width = 170, height = 42},
}

local function contains(control, x, y)
  return x >= control.x and x <= control.x + control.width
    and y >= control.y and y <= control.y + control.height
end

local function open(index)
  index = ((index - 1) % #assets) + 1
  local item = assets[index]
  local ok, document = pcall(thorvg.new, item.file, {
    width = stage.size,
    height = stage.size,
    autoplay = true,
    loop = true,
  })
  activeIndex = index
  if not ok then
    loadError = tostring(document)
    print('LOVE_THORVG_ERROR ' .. loadError)
    return
  end
  if active then active:release() end
  active = document
  loadError = nil
  print(('LOVE_THORVG_ASSET %s %.0f %.3f'):format(
    item.name, active.totalFrames, active.duration))
end

local function restart()
  if active then active:setProgress(0):play() end
end

local function togglePlayback()
  if not active then return end
  if active.playing then active:pause() else active:play() end
end

local function drawButton(control, label, primary)
  love.graphics.setColor(primary and palette.mint or palette.surface)
  love.graphics.rectangle('fill', control.x, control.y, control.width, control.height, 10, 10)
  if not primary then
    love.graphics.setColor(palette.rule)
    love.graphics.rectangle('line', control.x + 0.5, control.y + 0.5,
      control.width - 1, control.height - 1, 10, 10)
  end
  love.graphics.setColor(primary and palette.background or palette.paper)
  love.graphics.setFont(fonts.control)
  love.graphics.printf(label, control.x, control.y + 13, control.width, 'center')
end

function love.load()
  love.graphics.setBackgroundColor(palette.background)
  fonts.brand = love.graphics.newFont(18)
  fonts.meta = love.graphics.newFont(12)
  fonts.title = love.graphics.newFont(20)
  fonts.control = love.graphics.newFont(13)
  open(1)
  local major, minor, revision = love.getVersion()
  print(('LOVE_THORVG_READY LOVE=%d.%d.%d OS=%s ABI=2'):format(
    major, minor, revision, love.system.getOS()))
end

function love.update(dt)
  if active then active:update(dt) end
end

function love.draw()
  love.graphics.setColor(palette.stage)
  love.graphics.rectangle('fill', stage.x, stage.y, stage.size, stage.size)
  if active then active:draw(stage.x, stage.y) end

  love.graphics.setColor(palette.rule)
  love.graphics.rectangle('line', stage.x + 0.5, stage.y + 0.5,
    stage.size - 1, stage.size - 1)

  love.graphics.setColor(palette.overlay)
  love.graphics.rectangle('fill', stage.x, 580, stage.size, 68)

  love.graphics.setFont(fonts.brand)
  love.graphics.setColor(palette.paper)
  love.graphics.print('love-thorvg', 32, 25)
  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(palette.mint)
  love.graphics.printf('LÖVE 11.x · LUA API · THORVG WASM', 0, 30, 688, 'right')

  love.graphics.setFont(fonts.title)
  love.graphics.setColor(loadError and palette.coral or palette.paper)
  love.graphics.print(loadError and 'Unable to render' or assets[activeIndex].name, 80, 600)
  love.graphics.setFont(fonts.meta)
  love.graphics.setColor(loadError and palette.coral or palette.muted)
  local detail = loadError or (active and ('%.0f frames · %.2fs · love.graphics.draw'):format(
    active.totalFrames, active.duration) or 'Loading')
  love.graphics.printf(detail, 80, 607, 560, 'right')

  drawButton(controls.previous, 'Previous', false)
  drawButton(controls.play, active and active.playing and 'Pause' or 'Play', true)
  drawButton(controls.restart, 'Restart', false)
  drawButton(controls.next, 'Next artwork', false)
end

function love.keypressed(key)
  if key == 'left' then open(activeIndex - 1)
  elseif key == 'right' then open(activeIndex + 1)
  elseif key == 'space' then togglePlayback()
  elseif key == 'r' then restart()
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  if contains(controls.previous, x, y) then open(activeIndex - 1)
  elseif contains(controls.play, x, y) then togglePlayback()
  elseif contains(controls.restart, x, y) then restart()
  elseif contains(controls.next, x, y) then open(activeIndex + 1)
  end
end

function love.quit()
  if active then active:release() end
  for _, font in pairs(fonts) do font:release() end
end
