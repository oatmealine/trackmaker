local config = require 'src.config'

local self = {}

function self.getScrollSpeed(beat)
  if not config.config.previewMode then return 1 end
  if not chart.chart then return 1 end

  local speed = 1
  for _, event in ipairs(chart.chart) do
    if event.beat > beat then
      return speed
    end
    if event.scroll then
      speed = event.scroll
    end
  end
  return speed
end

return self