local self = {}

local logs = {}
local t = 0

local LOG_LIFETIME = 4

function self.update(dt)
  t = t + dt
  for i = #logs, 1, -1 do
    local log = logs[i]
    local lifetime = t - log.t
    if lifetime > LOG_LIFETIME then
      table.remove(logs, i)
    end
  end
end

function self.draw()
  for i, log in ipairs(logs) do
    local y = 24 + 16 * (i - 1)
    local lifetime = t - log.t
    local alpha = math.min(1, LOG_LIFETIME - lifetime)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(log[1], 0, y, sw, 'right')
  end
end

function self.log(text)
  table.insert(logs, { text, t = t })
end

return self