package.path = '../../?.lua;../../?/init.lua;./?.lua;./?/init.lua;' .. package.path

local App = require('app')
local app

function love.load()
  app = App.new()
end

function love.resize()
  app:resize()
end

function love.update(dt)
  app:update(dt)
end

function love.keypressed(key)
  app:keypressed(key)
end

function love.draw()
  app:draw()
end

function love.quit()
  if app then app:release() end
end
