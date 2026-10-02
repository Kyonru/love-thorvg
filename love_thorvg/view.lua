-- A deliberately tiny bridge for immediate-mode UI libraries. Pass the returned
-- function wherever the UI expects a render callback (including ui.renderView).
return function(document)
  return function(x, y, width, height)
    document:resize(width, height)
    document:draw(x, y)
  end
end
