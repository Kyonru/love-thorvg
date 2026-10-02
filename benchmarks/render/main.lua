package.path = '../../?.lua;../../?/init.lua;' .. package.path

local thorvg = require('love_thorvg')

local sizes = {128, 256, 512}
local warmupFrames = 10
local sampleFrames = 120

local function milliseconds(seconds)
  return seconds * 1000
end

local function renderFrames(document, count)
  for index = 1, count do
    document:setProgress((index - 0.5) / count)
    assert(document:render(), 'benchmark progress must produce a new frame')
  end
end

function love.load()
  local major, minor, revision, codename = love.getVersion()
  local renderer, rendererVersion, vendor, device = love.graphics.getRendererInfo()
  print(('# love=%d.%d.%d (%s) os=%s'):format(major, minor, revision, codename, love.system.getOS()))
  print(('# renderer=%s version=%s vendor=%s device=%s'):format(
    renderer, rendererVersion, vendor, device))
  print('size_px,samples,raster_ms,upload_ms,total_ms')

  for _, size in ipairs(sizes) do
    local document = thorvg.new('assets/Relax.json', {
      width = size,
      height = size,
      autoplay = false,
    })
    renderFrames(document, warmupFrames)
    document:resetRenderStats()
    renderFrames(document, sampleFrames)

    local stats = document:getRenderStats()
    local raster = milliseconds(stats.averageRasterSeconds)
    local upload = milliseconds(stats.averageUploadSeconds)
    print(('%d,%d,%.6f,%.6f,%.6f'):format(
      size, stats.frames, raster, upload, raster + upload))
    document:release()
  end

  love.event.quit(0)
end
