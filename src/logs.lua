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
  local y = 24
  for _, log in ipairs(logs) do
    local lifetime = t - log.t
    local alpha = math.min(1, LOG_LIFETIME - lifetime)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf(log[1], 0, y, sw, 'right')
    y = y + 16 * alpha
  end
end

function self.logStdout(text)
  print(text)
end
function self.logFile(text)
  local timestamped = '[' .. os.date('%c') .. '] ' .. tostring(text)

  love.filesystem.append('trackmaker.log', timestamped .. '\n')
  self.logStdout(timestamped)
end
function self.log(text)
  self.logFile(text)
  table.insert(logs, { text, t = t })
end

love.filesystem.write('trackmaker.log', '')

return self