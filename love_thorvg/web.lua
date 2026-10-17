-- Experimental browser backend. This module intentionally avoids LuaJIT FFI:
-- love.js uses PUC Lua and preloads love_thorvg_web from the WebAssembly build.
local native = require('love_thorvg_web')
assert(native.abiVersion() == 2, 'love-thorvg web ABI mismatch')

local Document = {}
Document.__index = Document

local mimeTypes = {
  svg = 'svg',
  json = 'lottie+json',
  lot = 'lot',
  lottie = 'lottie+json',
}

local function extension(path)
  local value = path:match('%.([^./\\]+)$')
  return value and value:lower() or ''
end

local function clock()
  if love.timer then return love.timer.getTime() end
  return os.clock()
end

local function assetRoot(path)
  return path:match('^(.*[/\\])') or ''
end

local function makeAssetResolver(path, options)
  local root = options.assetRoot or assetRoot(path)
  local fontPaths = options.fonts or {}
  local custom = options.assetResolver
  local cache = {}

  return function(source, assetType)
    local key = assetType .. ':' .. source
    if cache[key] ~= nil then return cache[key] or nil end
    local ok, bytes
    if custom then
      ok, bytes = pcall(custom, source, assetType)
    else
      local relative = source
      if assetType == 'font' and source:sub(1, 5) == 'name:' then
        relative = fontPaths[source:sub(6)]
      end
      if relative then
        relative = relative:gsub('^[/\\]+', '')
        ok, bytes = pcall(love.filesystem.read, root .. relative)
      end
    end
    if not ok or bytes == nil then cache[key] = false; return nil end
    if type(bytes) ~= 'string' and bytes.getString then bytes = bytes:getString() end
    if type(bytes) ~= 'string' then cache[key] = false; return nil end
    cache[key] = bytes
    return bytes
  end
end

local function releaseFrameCache(self)
  for _, entry in pairs(self.frameCache) do entry.image:release() end
  self.frameCache = {}
  self.frameCacheSize = 0
  self.image = self.uploadImage
end

local function frameCacheKey(self)
  local frame = self.totalFrames > 1 and self.progress * (self.totalFrames - 1) or 0
  return math.floor(frame * 1000 + 0.5)
end

local function cacheFrame(self)
  local key = frameCacheKey(self)
  self.cacheClock = self.cacheClock + 1
  local image = love.graphics.newImage(self.imageData)
  image:setFilter(self.filter, self.filter)
  self.frameCache[key] = {image = image, used = self.cacheClock}
  self.frameCacheSize = self.frameCacheSize + 1
  self.image = image
  if self.frameCacheSize <= self.frameCacheLimit then return end
  local oldestKey, oldestUse
  for candidate, entry in pairs(self.frameCache) do
    if candidate ~= key and (not oldestUse or entry.used < oldestUse) then
      oldestKey, oldestUse = candidate, entry.used
    end
  end
  if oldestKey then
    self.frameCache[oldestKey].image:release()
    self.frameCache[oldestKey] = nil
    self.frameCacheSize = self.frameCacheSize - 1
    self.cacheEvictions = self.cacheEvictions + 1
  end
end

local function allocateTarget(self, width, height)
  assert(width >= 1 and height >= 1, 'render dimensions must be positive')
  self.width, self.height = math.floor(width + 0.5), math.floor(height + 0.5)
  releaseFrameCache(self)
  if self.imageData then self.imageData:release(); self.imageData = nil end
  if self.uploadImage then self.uploadImage:release(); self.uploadImage = nil end
  if self.frameCacheLimit == 0 then
    self.imageData = love.image.newImageData(self.width, self.height, 'rgba8')
    self.uploadImage = love.graphics.newImage(self.imageData)
    self.uploadImage:setFilter(self.filter, self.filter)
    self.image = self.uploadImage
  end
  self.dirty = true
end

function Document:setProgress(progress)
  progress = assert(tonumber(progress), 'progress must be a number')
  progress = math.max(0, math.min(1, progress))
  self.time = progress * self.duration
  if math.abs(progress - self.progress) >= 0.000001 then self.progress = progress; self.dirty = true end
  return self
end

function Document:seek(seconds)
  if self.duration <= 0 then return self:setProgress(0) end
  return self:setProgress(seconds / self.duration)
end

function Document:update(dt)
  if not self.playing or self.duration <= 0 then return false end
  local nextTime = self.time + dt * self.speed
  if self.loop then
    nextTime = nextTime % self.duration
  else
    nextTime = math.max(0, math.min(self.duration, nextTime))
    if nextTime == 0 or nextTime == self.duration then self.playing = false end
  end
  self.time = nextTime
  self:setProgress(nextTime / self.duration)
  return true
end

function Document:play() self.playing = true; return self end
function Document:pause() self.playing = false; return self end

function Document:resize(width, height)
  width, height = math.floor(width + 0.5), math.floor(height + 0.5)
  if width ~= self.width or height ~= self.height then allocateTarget(self, width, height) end
  return self
end

function Document:clearCache() releaseFrameCache(self); self.dirty = true; return self end

function Document:getCacheStats()
  return {enabled = self.frameCacheLimit > 0, size = self.frameCacheSize,
    limit = self.frameCacheLimit, hits = self.cacheHits, misses = self.cacheMisses,
    evictions = self.cacheEvictions}
end

function Document:getRenderStats()
  local frames = self.renderedFrames
  return {frames = frames, lastRasterSeconds = self.lastRasterSeconds,
    lastUploadSeconds = self.lastUploadSeconds, totalRasterSeconds = self.totalRasterSeconds,
    totalUploadSeconds = self.totalUploadSeconds,
    averageRasterSeconds = frames > 0 and self.totalRasterSeconds / frames or 0,
    averageUploadSeconds = frames > 0 and self.totalUploadSeconds / frames or 0,
    lastCacheHit = self.lastCacheHit}
end

function Document:resetRenderStats()
  self.renderedFrames, self.lastRasterSeconds, self.lastUploadSeconds = 0, 0, 0
  self.totalRasterSeconds, self.totalUploadSeconds, self.lastCacheHit = 0, 0, false
  return self
end

function Document:render()
  assert(self.handle ~= nil, 'document has been released')
  if not self.dirty then return false end
  if self.frameCacheLimit > 0 then
    local entry = self.frameCache[frameCacheKey(self)]
    if entry then
      self.cacheClock = self.cacheClock + 1
      entry.used, self.image = self.cacheClock, entry.image
      self.cacheHits, self.lastRasterSeconds, self.lastUploadSeconds = self.cacheHits + 1, 0, 0
      self.lastCacheHit, self.dirty = true, false
      return false
    end
    self.cacheMisses = self.cacheMisses + 1
  end
  local rasterStarted = clock()
  local pixels, err = native.render(self.handle, self.width, self.height, self.progress)
  if not pixels then error(err or 'ThorVG render failed', 2) end
  local rasterSeconds = clock() - rasterStarted
  local uploadStarted = clock()
  local nextImageData = love.image.newImageData(self.width, self.height, 'rgba8', pixels)
  if self.imageData then self.imageData:release() end
  self.imageData = nextImageData
  if self.frameCacheLimit > 0 then
    cacheFrame(self)
  else
    self.uploadImage:replacePixels(self.imageData)
    self.image = self.uploadImage
  end
  local uploadSeconds = clock() - uploadStarted
  self.renderedFrames = self.renderedFrames + 1
  self.lastRasterSeconds, self.lastUploadSeconds = rasterSeconds, uploadSeconds
  self.totalRasterSeconds = self.totalRasterSeconds + rasterSeconds
  self.totalUploadSeconds = self.totalUploadSeconds + uploadSeconds
  self.lastCacheHit, self.dirty = false, false
  return true
end

function Document:draw(x, y, rotation, scaleX, scaleY, originX, originY)
  self:render()
  love.graphics.draw(self.image, x or 0, y or 0, rotation or 0, scaleX or 1,
    scaleY or scaleX or 1, originX or 0, originY or 0)
end

function Document:getImage() self:render(); return self.image end
function Document:getImageData()
  assert(self.frameCacheLimit == 0, 'getImageData is unavailable when frameCache is enabled')
  self:render(); return self.imageData
end

function Document:release()
  if not self.handle then return end
  native.release(self.handle)
  self.handle = nil
  releaseFrameCache(self)
  if self.uploadImage then self.uploadImage:release(); self.uploadImage = nil end
  self.image = nil
  if self.imageData then self.imageData:release(); self.imageData = nil end
end

local M = {_VERSION = native.version(), _EXPERIMENTAL_WEB = true, Document = Document}

function M.new(path, options)
  assert(love and love.filesystem and love.image and love.graphics, 'love-thorvg must run inside LÖVE')
  options = options or {}
  local bytes, readError = love.filesystem.read(path)
  assert(bytes, readError)
  if type(bytes) ~= 'string' and bytes.getString then bytes = bytes:getString() end
  local mimeType = options.mimeType or mimeTypes[extension(path)] or extension(path)
  local resolver = makeAssetResolver(path, options)
  local handle, duration, totalFrames, intrinsicWidth, intrinsicHeight = native.new(
    bytes, mimeType, options.resourcePath or '', options.threads or 0, resolver)
  if not handle then error(duration or 'ThorVG load failed for ' .. path, 2) end
  local self = setmetatable({handle = handle, assetResolver = resolver,
    duration = duration, totalFrames = totalFrames, intrinsicWidth = intrinsicWidth,
    intrinsicHeight = intrinsicHeight, filter = options.filter or 'linear',
    frameCacheLimit = math.max(0, math.floor(tonumber(options.frameCache) or 0)),
    frameCache = {}, frameCacheSize = 0, cacheClock = 0, cacheHits = 0,
    cacheMisses = 0, cacheEvictions = 0, renderedFrames = 0, lastRasterSeconds = 0,
    lastUploadSeconds = 0, totalRasterSeconds = 0, totalUploadSeconds = 0,
    lastCacheHit = false, progress = -1, time = 0, speed = options.speed or 1,
    loop = options.loop ~= false, playing = options.autoplay ~= false, dirty = true}, Document)
  allocateTarget(self, options.width or math.max(1, math.floor(intrinsicWidth + 0.5)),
    options.height or math.max(1, math.floor(intrinsicHeight + 0.5)))
  self:setProgress(options.progress or 0)
  return self
end

return M
