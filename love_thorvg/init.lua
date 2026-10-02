local ffi = require('ffi')

ffi.cdef [[
typedef struct love_thorvg_document love_thorvg_document;
uint32_t love_thorvg_abi_version(void);
const char* love_thorvg_version(void);
int love_thorvg_document_create(const void* data, size_t size, const char* mime_type,
  const char* resource_path, unsigned threads, love_thorvg_document** out_document,
  char* error, size_t error_capacity);
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
assert(native.love_thorvg_abi_version() == 1, 'love-thorvg native ABI mismatch')

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

local function allocateTarget(self, width, height)
  assert(width >= 1 and height >= 1, 'render dimensions must be positive')
  self.width = math.floor(width + 0.5)
  self.height = math.floor(height + 0.5)
  self.imageData = love.image.newImageData(self.width, self.height, 'rgba8')
  if self.image then
    self.image:release()
    self.image = nil
  end
  self.image = love.graphics.newImage(self.imageData)
  self.image:setFilter(self.filter, self.filter)
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

function Document:render()
  assert(self.handle ~= nil, 'document has been released')
  if not self.dirty then return false end
  local errorBuffer = ffi.new('char[512]')
  local result = native.love_thorvg_document_render(
    self.handle,
    ffi.cast('uint32_t*', imagePointer(self.imageData)),
    self.width,
    self.height,
    self.width,
    self.progress,
    errorBuffer,
    512)
  if result ~= 0 then error(nativeError(errorBuffer, 'ThorVG render failed'), 2) end
  self.image:replacePixels(self.imageData)
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

function Document:release()
  if not self.handle then return end
  local handle = self.handle
  ffi.gc(handle, nil)
  native.love_thorvg_document_destroy(handle)
  self.handle = nil
  if self.image then self.image:release(); self.image = nil end
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
  local result = native.love_thorvg_document_create(
    bytes, #bytes, mimeType, options.resourcePath or '', options.threads or 0,
    output, errorBuffer, 512)
  if result ~= 0 then error(nativeError(errorBuffer, 'ThorVG load failed for ' .. path), 2) end

  local handle = ffi.gc(output[0], native.love_thorvg_document_destroy)
  local intrinsicWidth = native.love_thorvg_document_intrinsic_width(handle)
  local intrinsicHeight = native.love_thorvg_document_intrinsic_height(handle)
  local self = setmetatable({
    handle = handle,
    duration = tonumber(native.love_thorvg_document_duration(handle)),
    totalFrames = tonumber(native.love_thorvg_document_total_frames(handle)),
    intrinsicWidth = tonumber(intrinsicWidth),
    intrinsicHeight = tonumber(intrinsicHeight),
    filter = options.filter or 'linear',
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
