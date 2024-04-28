local self = {}

local conductor = require 'src.conductor'
local xdrv      = require 'lib.xdrv'
local chart     = require 'src.chart'

local PAD_BOTTOM = 96

local NOTE_WIDTH = 48
local NOTE_HEIGHT = 10
local GAP_WIDTH = 48

local BACK_COL = hex('141214')
local SEP_COL = hex('86898c')
local LANE_1_COL = hex('4fccff')
local LANE_2_COL = hex('ff9cf5')
local MEASURE_COL = hex('373138')

local zoom = 1

local SCROLL_SPEED = 60

local function getScrollSpeed()
  return SCROLL_SPEED * zoom
end

local function scale()
  return math.min(zoom, 1)
end

local function getColumnX(i)
  if i < 4 then
    return -GAP_WIDTH/2 - NOTE_WIDTH * (3 - i + 0.5)
  else
    return GAP_WIDTH/2 + NOTE_WIDTH * (i - 3 - 0.5)
  end
end

local function getColumnColor(i)
  if i == 1 then
    return hex('ab80ff')
  elseif i == 2 then
    return hex('ffd454')
  elseif i == 3 then
    return hex('ffffff')
  elseif i == 4 then
    return hex('ffffff')
  elseif i == 5 then
    return hex('ffd454')
  elseif i == 6 then
    return hex('ab80ff')
  end
  return hex('ffffff')
end

local function beatToY(b)
  return love.graphics.getHeight() - PAD_BOTTOM - (b - conductor.beat) * getScrollSpeed()
end
local function yToBeat(y)
  return (love.graphics.getHeight() - PAD_BOTTOM - y) / getScrollSpeed() + conductor.beat
end

local function getLeft()
  return (-GAP_WIDTH/2 - NOTE_WIDTH * 3) * scale()
end
local function getRight()
  return -getLeft()
end
local function getMLeft()
  return -GAP_WIDTH/2 * scale()
end
local function getMRight()
  return -getMLeft()
end

function self.draw()
  sw, sh = love.graphics.getDimensions()
  scx, scy = sw/2, sh/2

  if not chart.loaded then
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf('No chart opened... (click to open)', 0, scy, sw, 'center')
    return
  end

  love.graphics.push()
  love.graphics.translate(scx, 0)

  love.graphics.setColor(BACK_COL:unpack())
  love.graphics.rectangle('fill', getLeft(), 0, getMLeft() - getLeft(), sh)
  love.graphics.rectangle('fill', getMRight(), 0, getRight() - getMRight(), sh)

  local topB = math.floor(yToBeat(0))
  local botB = math.ceil(yToBeat(sh))

  local measureSize = 4
  love.graphics.setLineWidth(1 * scale())
  for b = botB, topB do
    local y = beatToY(b)

    if b % measureSize == 0 then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(tostring(b / measureSize), getRight() + 4, y - fonts.inter_12:getHeight()/2)

      love.graphics.setColor(MEASURE_COL:unpack())
    elseif b % measureSize == 2 then
      love.graphics.setColor(MEASURE_COL:alpha(0.5):unpack())
    else
      love.graphics.setColor(0, 0, 0, 0)
    end

    love.graphics.line(getLeft(), y, getMLeft(), y)
    love.graphics.line(getRight(), y, getMRight(), y)
  end

  love.graphics.setColor(SEP_COL:unpack())
  for o = -1, 1, 2 do
    for i = 1, 2 do
      local x = o * (GAP_WIDTH/2 + NOTE_WIDTH * i) * scale()
      love.graphics.line(x, 0, x, sh)
    end
  end

  love.graphics.setColor(LANE_1_COL:alpha(0.8):unpack())
  love.graphics.line(getLeft(), sh, getLeft(), 0)
  love.graphics.line(getMLeft(), sh, getMLeft(), 0)
  love.graphics.setColor(LANE_2_COL:alpha(0.8):unpack())
  love.graphics.line(getRight(), sh, getRight(), 0)
  love.graphics.line(getMRight(), sh, getMRight(), 0)

  local events = chart.chart

  for _, event in ipairs(events) do
    if event.gearShift then
      local gear = event.gearShift

      local color
      local offset = 1
      if gear.lane == xdrv.XDRVLane.Left then
        color = LANE_1_COL
        offset = -1
      else
        color = LANE_2_COL
      end

      local y = beatToY(event.beat)
      local yEnd = beatToY(event.beat + gear.length)

      if y < -NOTE_HEIGHT/2 then break end
      if yEnd < sh then
        love.graphics.setLineWidth(3 * scale())

        love.graphics.setColor(color:alpha(0.3):unpack())
        love.graphics.rectangle('fill', (GAP_WIDTH/2) * offset * scale(), yEnd, NOTE_WIDTH * 3 * offset * scale(), y - yEnd)
        love.graphics.setColor(color:unpack())
        love.graphics.line(getRight() * offset, y, getMRight() * offset, y)
        love.graphics.line(getRight() * offset, yEnd, getMRight() * offset, yEnd)
      end
    end
  end

  for _, event in ipairs(events) do
    if event.note then
      local note = event.note
      local x = getColumnX(note.column) * scale()
      local y = beatToY(event.beat)
      local yEnd = beatToY(event.beat + (note.length or 0))

      if y < -NOTE_HEIGHT/2 then break end
      if yEnd < sh then
        if note.length then
          love.graphics.setColor(getColumnColor(note.column):alpha(0.5):unpack())
          love.graphics.rectangle('fill', x - (NOTE_WIDTH/2) * scale(), yEnd, NOTE_WIDTH * scale(), y - yEnd)
        end

        love.graphics.setColor(getColumnColor(note.column):unpack())
        love.graphics.rectangle('fill', x - (NOTE_WIDTH/2) * scale(), y - (NOTE_HEIGHT/2) * scale(), NOTE_WIDTH * scale(), NOTE_HEIGHT * scale())
      end
    end
  end

  love.graphics.setColor(BACK_COL:alpha(0.8):unpack())
  love.graphics.rectangle('fill', getLeft(), sh - PAD_BOTTOM, getMLeft() - getLeft(), PAD_BOTTOM)
  love.graphics.rectangle('fill', getRight(), sh - PAD_BOTTOM, getMRight() - getRight(), PAD_BOTTOM)

  love.graphics.setLineWidth(5 * scale())
  love.graphics.setColor(LANE_1_COL:unpack())
  love.graphics.line(getLeft(), sh - PAD_BOTTOM, getMLeft(), sh - PAD_BOTTOM)
  love.graphics.setColor(LANE_2_COL:unpack())
  love.graphics.line(getRight(), sh - PAD_BOTTOM, getMRight(), sh - PAD_BOTTOM)

  love.graphics.pop()
end

function self.wheelmoved(delta)
  if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    zoom = zoom * (1 + math.max(math.min(delta / 12, 0.5), -0.5))
  else
    conductor.seekDelta(delta * 0.7 / zoom)
  end
end

return self