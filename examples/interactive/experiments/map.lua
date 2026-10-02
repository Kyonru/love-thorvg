local regions = require('experiments.map_regions')

local Map = {}
Map.__index = Map

local function colorKey(red, green, blue)
  return ('%d:%d:%d'):format(
    math.floor(red * 255 + 0.5),
    math.floor(green * 255 + 0.5),
    math.floor(blue * 255 + 0.5))
end

function Map.new(thorvg)
  local lookup = {}
  for index, region in ipairs(regions) do
    lookup[('%d:%d:%d'):format(region.color[1], region.color[2], region.color[3])] = index
  end

  return setmetatable({
    artwork = thorvg.new('assets/dominican-republic.svg', {
      width = 640,
      height = 435,
      autoplay = false,
      filter = 'linear',
    }),
    hitMap = thorvg.new('assets/dominican-republic-hit.svg', {
      width = 640,
      height = 435,
      autoplay = false,
      filter = 'nearest',
    }),
    presentation = thorvg.new('assets/dominican-republic-draw.json', {
      width = 640,
      height = 435,
      autoplay = false,
      loop = false,
      filter = 'linear',
    }),
    highlightShader = love.graphics.newShader([[
      extern vec3 targetColor;
      extern vec4 highlightColor;

      vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
      {
        vec4 region = Texel(texture, textureCoords);
        vec3 difference = abs(region.rgb - targetColor);
        if (region.a < 0.5 || max(max(difference.r, difference.g), difference.b) > 0.01) {
          discard;
        }
        return highlightColor * color;
      }
    ]]),
    regions = regions,
    lookup = lookup,
    rect = {x = 0, y = 0, width = 1, height = 1},
    focusIndex = 1,
    hoveredIndex = nil,
    selectedIndex = nil,
    inputMode = 'keyboard',
    pathCount = 34,
    presenting = true,
    presentationTime = 0,
    presentationFrame = 0,
  }, Map)
end

function Map:resize(stage)
  local maximumWidth = stage.size - 40
  local maximumHeight = stage.size - 40
  local width = maximumWidth
  local height = width * 544 / 800
  if height > maximumHeight then
    height = maximumHeight
    width = height * 800 / 544
  end

  self.rect.x = math.floor(stage.x + (stage.size - width) * 0.5)
  self.rect.y = math.floor(stage.y + (stage.size - height) * 0.5)
  self.rect.width = math.floor(width)
  self.rect.height = math.floor(height)

  local renderWidth = math.min(800, math.max(320, self.rect.width))
  local renderHeight = math.floor(renderWidth * 544 / 800 + 0.5)
  local presentationWidth = math.min(420, renderWidth)
  local presentationHeight = math.floor(presentationWidth * 544 / 800 + 0.5)
  self.artwork:resize(renderWidth, renderHeight)
  self.hitMap:resize(renderWidth, renderHeight)
  self.presentation:resize(presentationWidth, presentationHeight)
  self.artwork:render()
  self.hitMap:render()
  self.hitData = self.hitMap:getImageData()
end

function Map:update(dt, paused)
  if not self.presenting or paused then return end
  self.presentationTime = math.min(self.presentation.duration, self.presentationTime + dt)
  local frame = math.min(self.presentation.totalFrames - 1,
    math.floor(self.presentationTime * 30))
  if frame ~= self.presentationFrame then
    self.presentationFrame = frame
    self.presentation:setProgress(frame / (self.presentation.totalFrames - 1))
  end
  if self.presentationTime >= self.presentation.duration then self.presenting = false end
end

function Map:finishPresentation()
  if not self.presenting then return end
  self.presenting = false
  self.presentationTime = self.presentation.duration
  self.presentationFrame = self.presentation.totalFrames - 1
  self.presentation:setProgress(1)
end

function Map:sampleAt(x, y)
  local rect = self.rect
  if x < rect.x or y < rect.y or x >= rect.x + rect.width or y >= rect.y + rect.height then
    return nil
  end

  local pixelX = math.min(self.hitMap.width - 1,
    math.max(0, math.floor((x - rect.x) / rect.width * self.hitMap.width)))
  local pixelY = math.min(self.hitMap.height - 1,
    math.max(0, math.floor((y - rect.y) / rect.height * self.hitMap.height)))
  local red, green, blue = self.hitData:getPixel(pixelX, pixelY)
  local region = self.lookup[colorKey(red, green, blue)]
  if region then return region end

  -- Antialiased boundary pixels blend neighboring colors. Look just inside the
  -- nearest region so borders remain easy to acquire without geometric copies.
  for radius = 1, 2 do
    for offsetY = -radius, radius do
      for offsetX = -radius, radius do
        local sampleX = math.min(self.hitMap.width - 1, math.max(0, pixelX + offsetX))
        local sampleY = math.min(self.hitMap.height - 1, math.max(0, pixelY + offsetY))
        red, green, blue = self.hitData:getPixel(sampleX, sampleY)
        region = self.lookup[colorKey(red, green, blue)]
        if region then return region end
      end
    end
  end
  return nil
end

function Map:mousemoved(x, y)
  if self.presenting then return end
  self.hoveredIndex = self:sampleAt(x, y)
  if self.hoveredIndex then
    self.focusIndex = self.hoveredIndex
    self.inputMode = 'mouse'
  end
end

function Map:mousepressed(x, y, button)
  if button ~= 1 then return false end
  local region = self:sampleAt(x, y)
  if not region then return false end
  self:finishPresentation()
  self.focusIndex = region
  self.hoveredIndex = region
  self.selectedIndex = region
  self.inputMode = 'mouse'
  return true
end

function Map:touchpressed(x, y)
  local region = self:sampleAt(x, y)
  if not region then return false end
  self:finishPresentation()
  self.focusIndex = region
  self.selectedIndex = region
  self.hoveredIndex = nil
  self.inputMode = 'keyboard'
  return true
end

function Map:keypressed(key)
  local direction = ({left = -1, up = -1, right = 1, down = 1})[key]
  if direction then
    self:finishPresentation()
    self.focusIndex = (self.focusIndex - 1 + direction) % #self.regions + 1
    self.hoveredIndex = nil
    self.inputMode = 'keyboard'
    return true
  end
  if (key == 'return' or key == 'kpenter') and self.focusIndex then
    self:finishPresentation()
    self.selectedIndex = self.focusIndex
    return true
  end
  return false
end

function Map:activeIndex()
  return self.hoveredIndex or self.focusIndex
end

function Map:activeRegion()
  return self.regions[self:activeIndex()]
end

function Map:selectedRegion()
  return self.selectedIndex and self.regions[self.selectedIndex] or nil
end

function Map:drawHighlight(index, color, alpha)
  if not index then return end
  local encoded = self.regions[index].color
  self.highlightShader:send('targetColor', {
    encoded[1] / 255,
    encoded[2] / 255,
    encoded[3] / 255,
  })
  self.highlightShader:send('highlightColor', {color[1], color[2], color[3], alpha})
  love.graphics.setShader(self.highlightShader)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.hitMap:getImage(), self.rect.x, self.rect.y, 0,
    self.rect.width / self.hitMap.width, self.rect.height / self.hitMap.height)
  love.graphics.setShader()
end

function Map:draw(stage, theme)
  theme.setColor(theme.panel)
  love.graphics.rectangle('fill', stage.x - 1, stage.y - 1,
    stage.size + 2, stage.size + 2, 24, 24)

  theme.setColor(theme.ink)
  if self.presenting then
    love.graphics.draw(self.presentation:getImage(), self.rect.x, self.rect.y, 0,
      self.rect.width / self.presentation.width, self.rect.height / self.presentation.height)
  else
    love.graphics.draw(self.artwork:getImage(), self.rect.x, self.rect.y, 0,
      self.rect.width / self.artwork.width, self.rect.height / self.artwork.height)
    self:drawHighlight(self.selectedIndex, theme.cobalt, 0.78)
    local active = self:activeIndex()
    if active ~= self.selectedIndex then self:drawHighlight(active, theme.cyan, 0.62) end
  end

  theme.setColor(theme.line, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', stage.x, stage.y, stage.size, stage.size, 24, 24)
end

function Map:reset()
  self.focusIndex = 1
  self.hoveredIndex = nil
  self.selectedIndex = nil
  self.inputMode = 'keyboard'
  self.presenting = true
  self.presentationTime = 0
  self.presentationFrame = 0
  self.presentation:setProgress(0)
end

function Map:release()
  self.artwork:release()
  self.hitMap:release()
  self.presentation:release()
  self.highlightShader:release()
  self.hitData = nil
end

return Map
