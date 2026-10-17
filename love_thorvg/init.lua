-- Browser builds of LÖVE use PUC Lua rather than LuaJIT, so FFI is not
-- available. The experimental web runtime preloads a small C module instead.
if love and love.system and love.system.getOS and love.system.getOS() == 'Web' then
  return require('love_thorvg.web')
end

local ffi = require('ffi')

ffi.cdef [[
typedef struct love_thorvg_document love_thorvg_document;
typedef size_t (*love_thorvg_asset_resolver)(const char* source, int asset_type,
  void* buffer, size_t capacity, void* user_data);
uint32_t love_thorvg_abi_version(void);
const char* love_thorvg_version(void);
int love_thorvg_document_create(const void* data, size_t size, const char* mime_type,
  const char* resource_path, unsigned threads, love_thorvg_document** out_document,
  char* error, size_t error_capacity);
int love_thorvg_document_create_with_resolver(const void* data, size_t size,
  const char* mime_type, const char* resource_path, unsigned threads,
  love_thorvg_asset_resolver resolver, void* resolver_user_data,
  love_thorvg_document** out_document, char* error, size_t error_capacity);
void love_thorvg_document_destroy(love_thorvg_document* document);
int love_thorvg_document_render(love_thorvg_document* document, uint32_t* rgba_pixels,
  uint32_t width, uint32_t height, uint32_t stride_pixels, float progress,
  char* error, size_t error_capacity);
float love_thorvg_document_duration(const love_thorvg_document* document);
float love_thorvg_document_total_frames(const love_thorvg_document* document);
float love_thorvg_document_intrinsic_width(const love_thorvg_document* document);
float love_thorvg_document_intrinsic_height(const love_thorvg_document* document);
]]

local platformNames = {
  OSX = 'macos',
  Windows = 'windows',
  Linux = 'linux',
}

local libraryNames = {
  OSX = 'liblove_thorvg.dylib',
  Windows = 'love_thorvg.dll',
  Linux = 'liblove_thorvg.so',
}

local function moduleLibraryPath()
  if not love or not love.filesystem then return nil end
  local root = love.filesystem.getRealDirectory('love_thorvg/init.lua')
  local platform = platformNames[jit.os]
  local filename = libraryNames[jit.os]
  if not root or not platform or not filename then return nil end
  return table.concat({root, 'love_thorvg', 'native', platform .. '-' .. jit.arch, filename}, '/')
end

local function sourceLibraryPath()
  local source = debug.getinfo(1, 'S').source
  local platform = platformNames[jit.os]
  local filename = libraryNames[jit.os]
  if source:sub(1, 1) ~= '@' or not platform or not filename then return nil end
  local directory = source:sub(2):match('^(.*)[/\\][^/\\]+$')
  if not directory then return nil end
  return table.concat({directory, 'native', platform .. '-' .. jit.arch, filename}, '/')
end

local function loadNative()
  local attempts = {}
  local override = os.getenv('LOVE_THORVG_LIBRARY')
  local candidates = {}
  if override and override ~= '' then candidates[#candidates + 1] = override end
  local installedPath = moduleLibraryPath()
  if installedPath then candidates[#candidates + 1] = installedPath end
  local sourcePath = sourceLibraryPath()
  if sourcePath then candidates[#candidates + 1] = sourcePath end
  candidates[#candidates + 1] = 'love_thorvg'
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= '' then
      local ok, library = pcall(ffi.load, candidate)
      if ok then return library end
      attempts[#attempts + 1] = candidate .. ': ' .. tostring(library)
    end
  end
  error('love-thorvg native library was not found. Build and stage it first.\n' .. table.concat(attempts, '\n'), 2)
end

local native = loadNative()
assert(native.love_thorvg_abi_version() == 2, 'love-thorvg native ABI mismatch')

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

local function imagePointer(imageData)
  if imageData.getFFIPointer then return imageData:getFFIPointer() end
  return imageData:getPointer()
end

local function nativeError(buffer, fallback)
  local message = ffi.string(buffer)
  return message ~= '' and message or fallback
end

local function clock()
  if love.timer then return love.timer.getTime() end
  return os.clock()
end

local function releaseFrameCache(self)
  if not self.frameCache then return end
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

local function assetRoot(path)
  return path:match('^(.*[/\\])') or ''
end

local function makeAssetResolver(path, options)
  local root = options.assetRoot or assetRoot(path)
  local fontPaths = options.fonts or {}
  local custom = options.assetResolver
  local cache = {}

  local function readAsset(source, assetType)
    local key = assetType .. ':' .. source
    if cache[key] ~= nil then return cache[key] or nil end

    local ok, bytes
    if custom then
      ok, bytes = pcall(custom, source, assetType == 2 and 'font' or 'picture')
    else
      local relative = source
      if assetType == 2 and source:sub(1, 5) == 'name:' then
        relative = fontPaths[source:sub(6)]
      end
      if relative then
        relative = relative:gsub('^[/\\]+', '')
        ok, bytes = pcall(love.filesystem.read, root .. relative)
      end
    end

    if not ok or bytes == nil then
      cache[key] = false
      return nil
    end
    if type(bytes) ~= 'string' and bytes.getString then bytes = bytes:getString() end
    if type(bytes) ~= 'string' then
      cache[key] = false
      return nil
    end
    cache[key] = bytes
    return bytes
  end

  local callback = ffi.cast('love_thorvg_asset_resolver', function(source, assetType, buffer, capacity)
    local bytes = readAsset(ffi.string(source), assetType)
    if not bytes then return 0 end
    if buffer == nil or capacity < #bytes then return #bytes end
    ffi.copy(buffer, bytes, #bytes)
    return #bytes
  end)
  return callback
end

local function allocateTarget(self, width, height)
  assert(width >= 1 and height >= 1, 'render dimensions must be positive')
  self.width = math.floor(width + 0.5)
  self.height = math.floor(height + 0.5)
  releaseFrameCache(self)
  if self.imageData then
    self.imageData:release()
    self.imageData = nil
  end
  self.imageData = love.image.newImageData(self.width, self.height, 'rgba8')
  if self.uploadImage then
    self.uploadImage:release()
    self.uploadImage = nil
  end
  if self.frameCacheLimit == 0 then
    self.uploadImage = love.graphics.newImage(self.imageData)
    self.uploadImage:setFilter(self.filter, self.filter)
    self.image = self.uploadImage
  else
    self.image = nil
  end
  self.dirty = true
end

function Document:setProgress(progress)
  progress = assert(tonumber(progress), 'progress must be a number')
  progress = math.max(0, math.min(1, progress))
  self.time = progress * self.duration
  if math.abs(progress - self.progress) >= 0.000001 then
    self.progress = progress
    self.dirty = true
  end
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

function Document:play()
  self.playing = true
  return self
end

function Document:pause()
  self.playing = false
  return self
end

function Document:resize(width, height)
  width, height = math.floor(width + 0.5), math.floor(height + 0.5)
  if width ~= self.width or height ~= self.height then allocateTarget(self, width, height) end
  return self
end

function Document:clearCache()
  releaseFrameCache(self)
  self.dirty = true
  return self
end

function Document:getCacheStats()
  return {
    enabled = self.frameCacheLimit > 0,
    size = self.frameCacheSize,
    limit = self.frameCacheLimit,
    hits = self.cacheHits,
    misses = self.cacheMisses,
    evictions = self.cacheEvictions,
  }
end

function Document:getRenderStats()
  local frames = self.renderedFrames
  return {
    frames = frames,
    lastRasterSeconds = self.lastRasterSeconds,
    lastUploadSeconds = self.lastUploadSeconds,
    totalRasterSeconds = self.totalRasterSeconds,
    totalUploadSeconds = self.totalUploadSeconds,
    averageRasterSeconds = frames > 0 and self.totalRasterSeconds / frames or 0,
    averageUploadSeconds = frames > 0 and self.totalUploadSeconds / frames or 0,
    lastCacheHit = self.lastCacheHit,
  }
end

function Document:resetRenderStats()
  self.renderedFrames = 0
  self.lastRasterSeconds = 0
  self.lastUploadSeconds = 0
  self.totalRasterSeconds = 0
  self.totalUploadSeconds = 0
  self.lastCacheHit = false
  return self
end

function Document:render()
  assert(self.handle ~= nil, 'document has been released')
  if not self.dirty then return false end
  if self.frameCacheLimit > 0 then
    local entry = self.frameCache[frameCacheKey(self)]
    if entry then
      self.cacheClock = self.cacheClock + 1
      entry.used = self.cacheClock
      self.cacheHits = self.cacheHits + 1
      self.image = entry.image
      self.lastRasterSeconds = 0
      self.lastUploadSeconds = 0
      self.lastCacheHit = true
      self.dirty = false
      return false
    end
    self.cacheMisses = self.cacheMisses + 1
  end
  local errorBuffer = ffi.new('char[512]')
  local rasterStarted = clock()
  local result = native.love_thorvg_document_render(
    self.handle,
    ffi.cast('uint32_t*', imagePointer(self.imageData)),
    self.width,
    self.height,
    self.width,
    self.progress,
    errorBuffer,
    512)
  local rasterSeconds = clock() - rasterStarted
  if result ~= 0 then error(nativeError(errorBuffer, 'ThorVG render failed'), 2) end
  local uploadStarted = clock()
  if self.frameCacheLimit > 0 then
    cacheFrame(self)
  else
    self.uploadImage:replacePixels(self.imageData)
    self.image = self.uploadImage
  end
  local uploadSeconds = clock() - uploadStarted
  self.renderedFrames = self.renderedFrames + 1
  self.lastRasterSeconds = rasterSeconds
  self.lastUploadSeconds = uploadSeconds
  self.totalRasterSeconds = self.totalRasterSeconds + rasterSeconds
  self.totalUploadSeconds = self.totalUploadSeconds + uploadSeconds
  self.lastCacheHit = false
  self.dirty = false
  return true
end

function Document:draw(x, y, rotation, scaleX, scaleY, originX, originY)
  self:render()
  love.graphics.draw(self.image, x or 0, y or 0, rotation or 0, scaleX or 1, scaleY or scaleX or 1,
    originX or 0, originY or 0)
end

function Document:getImage()
  self:render()
  return self.image
end

function Document:getImageData()
  assert(self.frameCacheLimit == 0,
    'getImageData is unavailable when frameCache is enabled')
  self:render()
  return self.imageData
end

function Document:release()
  if not self.handle then return end
  local handle = self.handle
  ffi.gc(handle, nil)
  native.love_thorvg_document_destroy(handle)
  self.handle = nil
  if self.assetCallback then self.assetCallback:free(); self.assetCallback = nil end
  releaseFrameCache(self)
  if self.uploadImage then self.uploadImage:release(); self.uploadImage = nil end
  self.image = nil
  if self.imageData then self.imageData:release(); self.imageData = nil end
end

local M = {
  _VERSION = ffi.string(native.love_thorvg_version()),
}

function M.new(path, options)
  assert(love and love.filesystem and love.image and love.graphics, 'love-thorvg must run inside LÖVE')
  options = options or {}
  local bytes, sizeOrError = love.filesystem.read(path)
  assert(bytes, sizeOrError)

  local ext = extension(path)
  local mimeType = options.mimeType or mimeTypes[ext] or ext
  local output = ffi.new('love_thorvg_document*[1]')
  local errorBuffer = ffi.new('char[512]')
  local assetCallback = makeAssetResolver(path, options)
  local result = native.love_thorvg_document_create_with_resolver(
    bytes, #bytes, mimeType, options.resourcePath or '', options.threads or 0,
    assetCallback, nil, output, errorBuffer, 512)
  if result ~= 0 then
    assetCallback:free()
    error(nativeError(errorBuffer, 'ThorVG load failed for ' .. path), 2)
  end

  local handle = ffi.gc(output[0], native.love_thorvg_document_destroy)
  local intrinsicWidth = native.love_thorvg_document_intrinsic_width(handle)
  local intrinsicHeight = native.love_thorvg_document_intrinsic_height(handle)
  local self = setmetatable({
    handle = handle,
    assetCallback = assetCallback,
    duration = tonumber(native.love_thorvg_document_duration(handle)),
    totalFrames = tonumber(native.love_thorvg_document_total_frames(handle)),
    intrinsicWidth = tonumber(intrinsicWidth),
    intrinsicHeight = tonumber(intrinsicHeight),
    filter = options.filter or 'linear',
    frameCacheLimit = math.max(0, math.floor(tonumber(options.frameCache) or 0)),
    frameCache = {},
    frameCacheSize = 0,
    cacheClock = 0,
    cacheHits = 0,
    cacheMisses = 0,
    cacheEvictions = 0,
    renderedFrames = 0,
    lastRasterSeconds = 0,
    lastUploadSeconds = 0,
    totalRasterSeconds = 0,
    totalUploadSeconds = 0,
    lastCacheHit = false,
    progress = -1,
    time = 0,
    speed = options.speed or 1,
    loop = options.loop ~= false,
    playing = options.autoplay ~= false,
    dirty = true,
  }, Document)
  allocateTarget(self, options.width or math.max(1, math.floor(intrinsicWidth + 0.5)),
    options.height or math.max(1, math.floor(intrinsicHeight + 0.5)))
  self:setProgress(options.progress or 0)
  return self
end

M.Document = Document
return M
