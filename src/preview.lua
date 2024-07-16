local config = require 'src.config'

local self = {}

function self.getScrollSpeed(beat)
  if not config.config.previewMode then return 1 end
  if not chart.chart then return 1 end

  local speed = 1
  -- update i don't think scroll events work like this
  --[[
  for _, event in ipairs(chart.chart) do
    if event.beat > beat then
      return speed
    end
    if event.scroll then
      speed = event.scroll
    end
  end
  ]]
  return speed
end

return self