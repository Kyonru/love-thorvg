function love.conf(t)
  t.identity = 'love-thorvg-web-example'
  t.window.title = 'love-thorvg · real LÖVE web example'
  t.window.width = 720
  t.window.height = 720
  t.window.resizable = false
  t.window.highdpi = false
  t.modules.audio = false
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.sound = false
  t.modules.thread = false
  t.modules.video = false
end
