package.path = '../../?.lua;../../?/init.lua;' .. package.path

local thorvg = require('love_thorvg')

local function expect(value, message)
  assert(value, message)
end

function love.load()
  local document = thorvg.new('assets/animated.json', {
    width = 32,
    height = 32,
    autoplay = false,
    frameCache = 2,
  })

  expect(document:render(), 'first frame should render')
  document:setProgress(0.5)
  expect(document:render(), 'second frame should render')
  document:setProgress(0)
  expect(not document:render(), 'cached frame should skip rasterization and upload')

  local stats = document:getCacheStats()
  expect(stats.size == 2, 'cache should contain two frames')
  expect(stats.hits == 1 and stats.misses == 2, 'cache hit/miss counts should be exact')

  document:setProgress(1)
  expect(document:render(), 'third frame should render')
  stats = document:getCacheStats()
  expect(stats.size == 2 and stats.evictions == 1, 'cache should evict its LRU frame')

  document:clearCache()
  expect(document:getCacheStats().size == 0, 'clearCache should release every entry')
  document:resize(48, 48)
  expect(document:render(), 'document should remain usable after clearing and resizing')
  document:release()

  print('love-thorvg frame cache smoke test passed')
  love.event.quit(0)
end
