local thorvg = require('love_thorvg')

local App = {}
App.__index = App

local C = {
  soot = {0.025, 0.021, 0.019},
  charcoal = {0.055, 0.046, 0.040},
  ash = {0.145, 0.125, 0.105},
  bone = {0.890, 0.820, 0.680},
  dimBone = {0.460, 0.405, 0.330},
  gold = {0.690, 0.485, 0.205},
  sap = {0.720, 0.075, 0.045},
  hotSap = {1.000, 0.315, 0.120},
  venom = {0.455, 0.760, 0.180},
  ghost = {0.910, 0.565, 0.220},
  black = {0, 0, 0},
}

local function color(c, alpha)
  love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
end

local function clamp(value, low, high)
  return math.max(low, math.min(high, value))
end

local function approach(current, target, speed, dt)
  if current < target then return math.min(target, current + speed * dt) end
  return math.max(target, current - speed * dt)
end

local function smoothstep(value)
  value = clamp(value, 0, 1)
  return value * value * (3 - 2 * value)
end

local function roundedRect(mode, x, y, width, height, radius)
  love.graphics.rectangle(mode, x, y, width, height, radius, radius)
end

local function makeSapShader()
  return love.graphics.newShader([[
    extern number health;
    extern number time;
    extern number edgeWidth;
    extern vec3 deepColor;
    extern vec3 brightColor;

    vec4 effect(vec4 tint, Image mask, vec2 uv, vec2 screen)
    {
      vec4 source = Texel(mask, uv);
      float reach = abs(uv.x - 0.5) * 2.0;
      float organic = sin(uv.y * 51.0 + sin(uv.x * 23.0) * 2.0) * 0.014;
      float boundary = health + organic;
      float visible = 1.0 - smoothstep(boundary, boundary + edgeWidth, reach);
      float pulse = 0.72 + 0.28 * sin(time * 3.2 - reach * 8.0 + uv.y * 9.0);
      float rim = 1.0 - smoothstep(0.0, 0.055, abs(reach - boundary));
      vec3 ink = mix(deepColor, brightColor, clamp(pulse * 0.62 + rim * 0.65, 0.0, 1.0));
      return vec4(ink, source.a * visible * tint.a);
    }
  ]])
end

local function makeRevealShader()
  return love.graphics.newShader([[
    extern number damage;
    extern number flare;
    extern vec3 crackColor;

    vec4 effect(vec4 tint, Image mask, vec2 uv, vec2 screen)
    {
      vec4 source = Texel(mask, uv);
      float seed = fract(sin(dot(floor(uv * vec2(37.0, 19.0)), vec2(12.9898, 78.233))) * 43758.5453);
      float gate = smoothstep(seed - 0.16, seed + 0.06, damage);
      float core = 0.55 + flare * 1.35;
      return vec4(crackColor * core, source.a * gate * tint.a);
    }
  ]])
end

function App.new()
  local self = setmetatable({
    frame = thorvg.new('assets/reliquary-frame.svg', {width = 1000, height = 300, autoplay = false}),
    sapMask = thorvg.new('assets/sap-network.svg', {width = 1000, height = 300, autoplay = false}),
    cracks = thorvg.new('assets/cracks.svg', {width = 1000, height = 300, autoplay = false}),
    sapShader = makeSapShader(),
    revealShader = makeRevealShader(),
    fonts = {},
    health = 0.84,
    targetHealth = 0.84,
    lagHealth = 0.84,
    phase = 1,
    venom = false,
    time = 0,
    hitFlash = 0,
    shake = 0,
    message = 'THE ROOTS REMEMBER',
    messageTimer = 0,
    particles = {},
    quality = 1,
    layout = {},
  }, App)

  self.fonts.eyebrow = love.graphics.newFont(11)
  self.fonts.body = love.graphics.newFont(14)
  self.fonts.value = love.graphics.newFont(18)
  self.fonts.title = love.graphics.newFont(34)
  self.fonts.health = love.graphics.newFont(52)
  self.fonts.phase = love.graphics.newFont(12)
  love.graphics.setBackgroundColor(C.soot)
  love.graphics.setLineStyle('smooth')
  self:resize()
  return self
end

function App:resize()
  local width, height = love.graphics.getDimensions()
  local hudWidth = math.min(width - 64, 1100)
  local hudHeight = hudWidth * 0.30
  local x = (width - hudWidth) * 0.5
  local y = math.max(145, height * 0.40 - hudHeight * 0.5)
  self.layout = {x = x, y = y, width = hudWidth, height = hudHeight}

  local pixelWidth = math.floor(hudWidth * self.quality + 0.5)
  local pixelHeight = math.floor(hudHeight * self.quality + 0.5)
  self.frame:resize(pixelWidth, pixelHeight)
  self.sapMask:resize(pixelWidth, pixelHeight)
  self.cracks:resize(pixelWidth, pixelHeight)
end

function App:burst(amount, tint)
  local box = self.layout
  local centerX, centerY = box.x + box.width * 0.5, box.y + box.height * 0.52
  for index = 1, amount do
    local angle = math.random() * math.pi * 2
    local speed = 45 + math.random() * 160
    self.particles[#self.particles + 1] = {
      x = centerX + (math.random() - 0.5) * box.width * 0.22,
      y = centerY + (math.random() - 0.5) * box.height * 0.22,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed - 25,
      life = 0.45 + math.random() * 0.65,
      age = 0,
      size = 1 + math.random() * 3,
      tint = tint,
    }
  end
end

function App:setHealth(nextHealth, reason)
  nextHealth = clamp(nextHealth, 0, 1)
  if nextHealth < self.targetHealth then
    self.hitFlash = 1
    self.shake = math.min(1, self.shake + (self.targetHealth - nextHealth) * 5)
    self:burst(18, self.venom and C.venom or C.hotSap)
    self.message = reason or 'THE BARK SPLINTERS'
  elseif nextHealth > self.targetHealth then
    self:burst(12, C.bone)
    self.message = reason or 'SAP ASCENDS'
  end
  self.targetHealth = nextHealth
  self.messageTimer = 1.4
end

function App:keypressed(key)
  if key == 'left' then
    self:setHealth(self.targetHealth - 0.05)
  elseif key == 'right' then
    self:setHealth(self.targetHealth + 0.05)
  elseif key == 'space' then
    self:setHealth(self.targetHealth - 0.14, 'A LIMB IS SEVERED')
  elseif key == 'h' then
    self:setHealth(self.targetHealth + 0.12, 'THE GROVE ANSWERS')
  elseif key == 'v' then
    self.venom = not self.venom
    self.message = self.venom and 'BLIGHT ENTERS THE SAP' or 'THE BLIGHT RECEDES'
    self.messageTimer = 1.8
    self:burst(22, self.venom and C.venom or C.hotSap)
  elseif key == 'p' then
    self.phase = self.phase % 3 + 1
    self.message = ({'THE FIRST GROWTH', 'THE ORCHARD WAKES', 'THE ROOT CROWN OPENS'})[self.phase]
    self.messageTimer = 2
    self.hitFlash = 0.7
  elseif key == 'q' then
    self.quality = self.quality == 1 and 2 or 1
    self:resize()
    self.message = self.quality == 2 and 'VECTOR RASTER  2×' or 'VECTOR RASTER  1×'
    self.messageTimer = 1.8
  elseif key == 'r' then
    self.health, self.targetHealth, self.lagHealth = 0.84, 0.84, 0.84
    self.phase, self.venom = 1, false
    self.message, self.messageTimer = 'THE ROOTS REMEMBER', 1.6
    self.particles = {}
  elseif key == 'escape' then
    love.event.quit()
  end
end

function App:update(dt)
  dt = math.min(dt, 1 / 20)
  self.time = self.time + dt
  self.health = approach(self.health, self.targetHealth, 1.25, dt)
  if self.lagHealth < self.health then
    self.lagHealth = approach(self.lagHealth, self.health, 1.4, dt)
  elseif math.abs(self.health - self.targetHealth) < 0.01 then
    self.lagHealth = approach(self.lagHealth, self.health, 0.16, dt)
  end
  self.hitFlash = approach(self.hitFlash, 0, 3.8, dt)
  self.shake = approach(self.shake, 0, 4.2, dt)
  self.messageTimer = math.max(0, self.messageTimer - dt)

  for index = #self.particles, 1, -1 do
    local particle = self.particles[index]
    particle.age = particle.age + dt
    if particle.age >= particle.life then
      table.remove(self.particles, index)
    else
      particle.x = particle.x + particle.vx * dt
      particle.y = particle.y + particle.vy * dt
      particle.vy = particle.vy + 70 * dt
      particle.vx = particle.vx * (1 - dt * 1.8)
    end
  end
end

function App:drawAtmosphere()
  local width, height = love.graphics.getDimensions()
  color(C.charcoal)
  love.graphics.rectangle('fill', 0, 0, width, height)

  color(C.black, 0.34)
  for index = 0, 8 do
    local yy = height * (0.08 + index * 0.12)
    love.graphics.line(0, yy, width, yy + math.sin(index * 1.7) * 18)
  end

  color(C.ash, 0.14)
  for index = 1, 40 do
    local x = (index * 83 + math.sin(index * 4.1) * 31) % width
    local y = (index * 137) % height
    love.graphics.circle('fill', x, y, index % 3 == 0 and 2 or 1)
  end
end

function App:drawHeading()
  local width = love.graphics.getWidth()
  color(C.dimBone)
  love.graphics.setFont(self.fonts.eyebrow)
  love.graphics.printf('ENCOUNTER  VII  /  THE SUBTERRANEAN ORCHARD', 0, 46, width, 'center')

  color(C.bone)
  love.graphics.setFont(self.fonts.title)
  love.graphics.printf('MORROWROOT', 0, 68, width, 'center')

  color(C.gold)
  love.graphics.setLineWidth(1)
  love.graphics.line(width * 0.5 - 174, 118, width * 0.5 - 72, 118)
  love.graphics.circle('fill', width * 0.5, 118, 3)
  love.graphics.line(width * 0.5 + 72, 118, width * 0.5 + 174, 118)
end

function App:drawMaskedNetwork(health, alpha, deep, bright)
  local box = self.layout
  self.sapShader:send('health', health)
  self.sapShader:send('time', self.time)
  self.sapShader:send('edgeWidth', 0.012)
  self.sapShader:send('deepColor', deep)
  self.sapShader:send('brightColor', bright)
  love.graphics.setShader(self.sapShader)
  love.graphics.setColor(1, 1, 1, alpha)
  local image = self.sapMask:getImage()
  love.graphics.draw(image, box.x, box.y, 0, box.width / image:getWidth(), box.height / image:getHeight())
  love.graphics.setShader()
end

function App:drawRelic()
  local box = self.layout
  local jitterX = math.sin(self.time * 69) * self.shake * 4
  local jitterY = math.cos(self.time * 53) * self.shake * 2
  love.graphics.push()
  love.graphics.translate(jitterX, jitterY)

  color(C.black, 0.48)
  roundedRect('fill', box.x + 48, box.y + box.height * 0.23, box.width - 96, box.height * 0.54, 16)

  self:drawMaskedNetwork(self.lagHealth, 0.70, C.gold, C.ghost)
  self:drawMaskedNetwork(self.health, 1.00, self.venom and {0.10, 0.26, 0.025} or C.sap,
    self.venom and C.venom or C.hotSap)

  local frameImage = self.frame:getImage()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(frameImage, box.x, box.y, 0,
    box.width / frameImage:getWidth(), box.height / frameImage:getHeight())

  self.revealShader:send('damage', 1 - self.health)
  self.revealShader:send('flare', self.hitFlash)
  self.revealShader:send('crackColor', self.venom and C.venom or C.bone)
  love.graphics.setShader(self.revealShader)
  love.graphics.setBlendMode('add')
  local crackImage = self.cracks:getImage()
  love.graphics.draw(crackImage, box.x, box.y, 0,
    box.width / crackImage:getWidth(), box.height / crackImage:getHeight())
  love.graphics.setBlendMode('alpha')
  love.graphics.setShader()

  if self.phase >= 2 then
    local pulse = 0.52 + math.sin(self.time * 3.4) * 0.18
    color(self.phase == 3 and C.hotSap or C.gold, pulse)
    love.graphics.setLineWidth(2)
    local cx, cy = box.x + box.width * 0.5, box.y + box.height * 0.51
    love.graphics.circle('line', cx, cy, box.height * (self.phase == 3 and 0.205 or 0.175))
    if self.phase == 3 then
      love.graphics.circle('line', cx, cy, box.height * 0.235)
    end
  end
  love.graphics.pop()
end

function App:drawReadout()
  local box = self.layout
  local centerX = box.x + box.width * 0.5
  local healthPercent = math.floor(self.health * 100 + 0.5)
  local phaseNames = {'DORMANT BARK', 'FRUITING BODY', 'ROOT CROWN'}

  color(C.bone)
  love.graphics.setFont(self.fonts.health)
  love.graphics.printf(('%02d'):format(healthPercent), centerX - 130, box.y + box.height * 0.355, 260, 'center')
  color(C.dimBone)
  love.graphics.setFont(self.fonts.eyebrow)
  love.graphics.printf('VITAL SAP', centerX - 90, box.y + box.height * 0.60, 180, 'center')

  local phaseY = box.y + box.height + 22
  color(C.gold)
  love.graphics.setFont(self.fonts.phase)
  love.graphics.printf(('PHASE %s  ·  %s'):format(self.phase, phaseNames[self.phase]), 0, phaseY,
    love.graphics.getWidth(), 'center')

  local messageAlpha = self.messageTimer > 0 and smoothstep(math.min(1, self.messageTimer * 2)) or 0.36
  color(self.venom and C.venom or C.dimBone, messageAlpha)
  love.graphics.setFont(self.fonts.eyebrow)
  love.graphics.printf(self.message, 0, phaseY + 25, love.graphics.getWidth(), 'center')
end

function App:drawParticles()
  love.graphics.setBlendMode('add')
  for _, particle in ipairs(self.particles) do
    local fade = 1 - particle.age / particle.life
    color(particle.tint, fade * 0.85)
    love.graphics.circle('fill', particle.x, particle.y, particle.size * fade)
  end
  love.graphics.setBlendMode('alpha')
end

function App:drawControls()
  local width, height = love.graphics.getDimensions()
  local labels = {
    {'LEFT / RIGHT', 'shape health'},
    {'SPACE', 'strike'},
    {'H', 'restore'},
    {'V', 'blight'},
    {'P', 'phase'},
    {'Q', ('vector %d×'):format(self.quality)},
    {'R', 'restart'},
  }
  local totalWidth = math.min(width - 64, 850)
  local cell = totalWidth / #labels
  local startX = (width - totalWidth) * 0.5
  local y = height - 76
  color(C.ash, 0.9)
  love.graphics.line(startX, y - 17, startX + totalWidth, y - 17)

  for index, item in ipairs(labels) do
    local x = startX + (index - 1) * cell
    color(C.bone)
    love.graphics.setFont(self.fonts.body)
    love.graphics.printf(item[1], x, y, cell, 'center')
    color(C.dimBone)
    love.graphics.setFont(self.fonts.eyebrow)
    love.graphics.printf(item[2], x, y + 24, cell, 'center')
  end
end

function App:drawStats()
  local stats = love.graphics.getStats()
  color(C.dimBone, 0.72)
  love.graphics.setFont(self.fonts.eyebrow)
  love.graphics.print(('%03d FPS  ·  %02d DRAWS  ·  %.1f MiB'):format(
    love.timer.getFPS(), stats.drawcalls, stats.texturememory / 1048576), 24, love.graphics.getHeight() - 26)
end

function App:draw()
  self:drawAtmosphere()
  self:drawHeading()
  self:drawRelic()
  self:drawParticles()
  self:drawReadout()
  self:drawControls()
  self:drawStats()
end

function App:release()
  self.frame:release()
  self.sapMask:release()
  self.cracks:release()
  self.sapShader:release()
  self.revealShader:release()
  for _, font in pairs(self.fonts) do font:release() end
end

return App
