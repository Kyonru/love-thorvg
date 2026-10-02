package.path = '../../?.lua;../../?/init.lua;' .. package.path

local thorvg = require('love_thorvg')
local animation

function love.load()
  animation = thorvg.new('assets/sample.svg', {width = 320, height = 320})
end

function love.update(dt)
  animation:update(dt)
end

function love.draw()
  animation:draw(160, 64)
  love.graphics.print(('love-thorvg %s | %.0f frames | %.2fs'):format(
    thorvg._VERSION, animation.totalFrames, animation.duration), 12, 12)
end

function love.quit()
  animation:release()
end
