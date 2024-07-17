local xdrv = require 'lib.xdrv'

local MAGIC = 'wabung'

local self = {}

-- wabung$tB$>▭5+.5▭3+.5▭1+.5◨~4+1.5▭3~.5+1.5▭6~1+2▭3~.5+1▭5~.5
-- this format is completely ancient interface core but that's ok

-- wabung$tB$>▭2+.5▭31&▭6&▭35&▭4&▭3&▭5&▭13&▭5&▭3&▭5&▭3&▭1&◨~4+1.5▭3~.5&▭6~1+2▭3~.5+1▭5~.5
-- wabung$tB$>▭46+.5▭5&▭4&▭2&▭31&▭6&▭35&▭4&▭3&▭5&▭13&▭5&▭3&▭5&▭3&▭1&◨~4+1.5▭3~.5&▭6~1

local SYMBOLS = {
  PLUS = '+',
  PLUS_REPEAT = '&',
  HOLD = '~',
  NOTE = '▭',
  GEAR_LEFT = '◧',
  GEAR_RIGHT = '◨',
  DRIFT_LEFT = '◁',
  DRIFT_RIGHT = '▷',
  DRIFT_NEUTRAL = '◇',
}

---@param number number
---@return string
local function formatNum(number)
  local n = tostring(number)
  if string.sub(n, 1, 1) == '0' then
    n = string.sub(n, 2)
  end
  return n
end
---@param str string
---@return number?
local function readNum(str)
  return tonumber('0' .. str)
end

---@param things XDRVThing[]
---@param opt? { useSeconds: boolean? }
---@return string
function self.encode(things, opt)
  opt = opt or {}

  local clip = { }

  local lastGap
  local lastWasNote = false
  local b = things[1].beat
  for _, thing in ipairs(things) do
    if thing.beat > b then
      local gap = thing.beat - b
      if gap == lastGap then
        table.insert(clip, SYMBOLS.PLUS_REPEAT)
      else
        lastGap = gap
        table.insert(clip, SYMBOLS.PLUS .. formatNum(thing.beat - b))
      end
      b = thing.beat
      lastWasNote = false
    end
    if thing.note then
      local isHold = thing.note.length ~= nil
      if isHold then lastWasNote = false end
      if lastWasNote then
        -- compact chords
        table.insert(clip, thing.note.column)
      else
        table.insert(clip, SYMBOLS.NOTE .. thing.note.column .. (isHold and (SYMBOLS.HOLD .. formatNum(thing.note.length)) or ''))
      end
      lastWasNote = true
    else
      lastWasNote = false
    end
    if thing.gearShift then
      local char = thing.gearShift.lane == xdrv.XDRVLane.Left and SYMBOLS.GEAR_LEFT or SYMBOLS.GEAR_RIGHT
      table.insert(clip, char .. SYMBOLS.HOLD .. formatNum(thing.gearShift.length))
    end
    if thing.drift then
      local char = SYMBOLS.DRIFT_NEUTRAL
      if thing.drift.direction == xdrv.XDRVDriftDirection.Left then
        char = SYMBOLS.DRIFT_LEFT
      elseif thing.drift.direction == xdrv.XDRVDriftDirection.Right then
        char = SYMBOLS.DRIFT_RIGHT
      end
      table.insert(clip, char)
    end
  end

  local meta = {}

  table.insert(meta, MAGIC)
  -- timing
  table.insert(meta, 't' .. (opt.useSeconds and 'S' or 'B'))
  -- chart
  table.insert(meta, '>' .. table.concat(clip, ''))

  return table.concat(meta, '$')
end

---@param str string
---@return XDRVThing[]?
function self.decode(str)
  local isValid = string.find(str, '^wabung%$')
  if not isValid then return end

  local useSeconds = false
  local things = {}

  for segment in string.gmatch(str, '[^$]+') do
    local char = utf8sub(segment, 1, 1)
    local data = utf8sub(segment, 2)
    if char == 'w' then
      -- wabung; trackmaker magic bytes, ignore
    elseif char == 't' then
      -- timing
      useSeconds = data == 'S'
    elseif char == '>' then
      -- notedata
      local b = 0
      local lastGap
      local buf = data

      local thingBuffer = nil

      while true do
        if #buf == 0 then break end
        local type = utf8sub(buf, 1, 1)
        local num, rest = string.match(utf8sub(buf, 2), '([%d.]*)(.*)')
        if not num then break end
        if not rest then break end
        buf = rest

        if type == SYMBOLS.HOLD and thingBuffer then
          if thingBuffer.note then
            thingBuffer.note.length = readNum(num)
          elseif thingBuffer.gearShift then
            thingBuffer.gearShift.length = readNum(num)
          end
        else
          if thingBuffer ~= nil then table.insert(things, thingBuffer) end
          thingBuffer = nil

          if type == SYMBOLS.NOTE then
            if #num > 1 then
              -- compact chords
              for col in string.gmatch(num, '%d') do
                table.insert(things, { beat = b, note = { column = tonumber(col) } })
              end
            else
              thingBuffer = { beat = b, note = { column = readNum(num) } }
            end
          elseif type == SYMBOLS.GEAR_LEFT or type == SYMBOLS.GEAR_RIGHT then
            local lane = type == SYMBOLS.GEAR_LEFT and xdrv.XDRVLane.Left or xdrv.XDRVLane.Right
            thingBuffer = { beat = b, gearShift = { lane = lane } }
          elseif type == SYMBOLS.DRIFT_LEFT or type == SYMBOLS.DRIFT_RIGHT or type == SYMBOLS.DRIFT_NEUTRAL then
            local dir = xdrv.XDRVDriftDirection.Neutral
            if type == SYMBOLS.DRIFT_LEFT then
              dir = xdrv.XDRVDriftDirection.Left
            elseif type == SYMBOLS.DRIFT_RIGHT then
              dir = xdrv.XDRVDriftDirection.Right
            end
            thingBuffer = { beat = b, drift = { direction = dir } }
          elseif type == SYMBOLS.PLUS then
            local gap = readNum(num)
            lastGap = gap
            b = b + gap
          elseif type == SYMBOLS.PLUS_REPEAT then
            b = b + lastGap
          end
        end
      end

      if thingBuffer ~= nil then table.insert(things, thingBuffer) end
    end
  end

  return things
end

return self