package.path = '../../?.lua;../../?/init.lua;./?.lua;' .. package.path

local Browser = require('browser')
local browser

function love.load(args)
  browser = Browser.new(args)
end

function love.resize()
  browser:resize()
end

function love.update(dt)
  browser:update(dt)
end

function love.keypressed(key)
  browser:keypressed(key)
end

function love.draw()
  browser:draw()
end

function love.quit()
  if browser then browser:release() end
end
