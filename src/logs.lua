local self = {}

local logs = {}
local t = 0

---@type string[]
local appendBuffer = {}
local appendBufferTimer = 0
local APPEND_BUFFER_INTERVAL = 0.1

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
  if #appendBuffer > 0 then
    appendBufferTimer = appendBufferTimer - dt
    if appendBufferTimer < 0 then
      love.filesystem.append('trackmaker.log', table.concat(appendBuffer, ''))
      appendBuffer = {}
    end
  end
end

function self.draw()
  local y = 24
  for _, log in ipairs(logs) do
    local lifetime = t - log.t
    local alpha = math.min(1, LOG_LIFETIME - lifetime)
    local width = love.graphics.getFont():getWidth(log[1])
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle('fill', love.graphics.getWidth() - 24 - width - 4, y, width + 4 + 4, 16 * alpha)
    love.graphics.setColor(0, 0, 0, alpha * alpha * 0.4)
    love.graphics.printf(log[1], 2, y + 2, love.graphics.getWidth() - 24, 'right')
    love.graphics.setColor(1, 1, 1, alpha)
    if log.warning then
      local b = 0.7 + math.sin(love.timer.getTime() * 3) * 0.3
      love.graphics.setColor(1, 0.5 * b, 0.3 * b, alpha)
    end
    love.graphics.printf(log[1], 0, y, love.graphics.getWidth() - 24, 'right')
    y = y + 16 * alpha
  end
end

function self.logStdout(text)
  print(text)
end
function self.logFile(text)
  local timestamped = '[' .. os.date('%c') .. '] ' .. tostring(text)

  table.insert(appendBuffer, timestamped .. '\n')
  appendBufferTimer = APPEND_BUFFER_INTERVAL
  self.logStdout(timestamped)
end
function self.log(text)
  self.logFile(text)
  table.insert(logs, { text, t = t })
end
function self.warn(text)
  self.logFile('WARN: ' .. text)
  table.insert(logs, { text, t = t + 8, warning = true })
end
-- what's uplog
function self.uplog(id, text)
  self.logFile(text)
  for _, log in ipairs(logs) do
    if log.id == id then
      log.t = t
      log[1] = text
      return
    end
  end
  table.insert(logs, { text, t = t, id = id })
end

love.filesystem.write('trackmaker.log', '')

return self