local theme = {
  background = {0.035, 0.047, 0.098},
  panel = {0.065, 0.082, 0.155},
  panelRaised = {0.086, 0.106, 0.196},
  ink = {0.895, 0.925, 1.000},
  muted = {0.565, 0.620, 0.765},
  line = {0.190, 0.225, 0.380},
  cobalt = {0.310, 0.380, 1.000},
  coral = {1.000, 0.430, 0.350},
  cyan = {0.230, 0.850, 0.920},
  yellow = {1.000, 0.800, 0.260},
}

function theme.setColor(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

return theme
