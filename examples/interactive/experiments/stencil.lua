local Stencil = {}
Stencil.__index = Stencil

function Stencil.new(thorvg)
  return setmetatable({
    mask = thorvg.new('assets/mask.svg', {
      width = 600,
      height = 600,
      autoplay = false,
      filter = 'linear',
    }),
    shader = love.graphics.newShader([[
      extern number cutoff;

      vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
      {
        vec4 pixel = Texel(texture, texture_coords);
        if (pixel.a < cutoff) discard;
        return pixel * color;
      }
    ]]),
    rotation = -0.12,
    cutoff = 0.5,
    enabled = true,
  }, Stencil)
end

function Stencil:resize(stage)
  self.mask:resize(stage.size, stage.size)
end

function Stencil:update(dt, paused)
  if paused then return end
  local rotationSpeed = 1.15
  if love.keyboard.isDown('left') then self.rotation = self.rotation - rotationSpeed * dt end
  if love.keyboard.isDown('right') then self.rotation = self.rotation + rotationSpeed * dt end
  if love.keyboard.isDown('up') then self.cutoff = math.min(0.95, self.cutoff + dt * 0.5) end
  if love.keyboard.isDown('down') then self.cutoff = math.max(0.05, self.cutoff - dt * 0.5) end
end

function Stencil:keypressed(key)
  if key ~= 's' then return false end
  self.enabled = not self.enabled
  return true
end

function Stencil:drawMask(stage)
  local centerX = stage.x + stage.size * 0.5
  local centerY = stage.y + stage.size * 0.5
  love.graphics.draw(self.mask:getImage(), centerX, centerY, self.rotation, 1, 1,
    stage.size * 0.5, stage.size * 0.5)
end

function Stencil:drawMovingField(stage, elapsed, fonts, theme)
  local x, y, size = stage.x, stage.y, stage.size
  theme.setColor(theme.cobalt)
  love.graphics.rectangle('fill', x - size * 0.2, y - size * 0.2, size * 1.4, size * 1.4)

  local drift = (elapsed * 74) % (size * 0.5)
  love.graphics.push()
  love.graphics.translate(x + size * 0.5, y + size * 0.5)
  love.graphics.rotate(-0.42)
  for index = -5, 5 do
    local bandX = index * size * 0.22 + drift - size * 0.25
    theme.setColor(index % 2 == 0 and theme.coral or theme.yellow, 0.92)
    love.graphics.rectangle('fill', bandX, -size, size * 0.105, size * 2)
  end
  love.graphics.pop()

  theme.setColor(theme.cyan, 0.88)
  love.graphics.circle('fill', x + size * (0.25 + 0.08 * math.sin(elapsed * 0.9)),
    y + size * (0.30 + 0.06 * math.cos(elapsed * 1.1)), size * 0.14)
  theme.setColor(theme.background, 0.75)
  love.graphics.circle('fill', x + size * (0.73 + 0.05 * math.cos(elapsed * 0.7)),
    y + size * (0.72 + 0.08 * math.sin(elapsed)), size * 0.18)

  theme.setColor(theme.ink, 0.95)
  love.graphics.setFont(fonts.stage)
  love.graphics.printf('DRAW\nINSIDE', x + size * 0.13, y + size * 0.38,
    size * 0.74, 'center')
end

function Stencil:draw(stage, elapsed, fonts, theme)
  theme.setColor(theme.panel)
  love.graphics.rectangle('fill', stage.x - 1, stage.y - 1,
    stage.size + 2, stage.size + 2, 24, 24)

  if self.enabled then
    self.shader:send('cutoff', self.cutoff)
    love.graphics.stencil(function()
      love.graphics.setShader(self.shader)
      self:drawMask(stage)
      love.graphics.setShader()
    end, 'replace', 1)
    love.graphics.setStencilTest('equal', 1)
    self:drawMovingField(stage, elapsed, fonts, theme)
    love.graphics.setStencilTest()
  else
    love.graphics.setScissor(stage.x, stage.y, stage.size, stage.size)
    self:drawMovingField(stage, elapsed, fonts, theme)
    love.graphics.setScissor()
    theme.setColor(theme.ink, 0.13)
    self:drawMask(stage)
  end

  theme.setColor(theme.ink, 0.10)
  self:drawMask(stage)
  theme.setColor(theme.line, 0.9)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', stage.x, stage.y, stage.size, stage.size, 24, 24)
end

function Stencil:reset()
  self.rotation = -0.12
  self.cutoff = 0.5
  self.enabled = true
end

function Stencil:release()
  self.mask:release()
  self.shader:release()
end

return Stencil
