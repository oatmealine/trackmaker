local conductor = require 'src.conductor'
require 'lib.color'
local xdrv = require 'lib.xdrv'
local nfd = require 'nfd'
require 'src.util'

local t = {}
t.window = {}
t.modules = {}
require 'conf'
love.conf(t)
release = t.releases

local chart
local chartDir

local PAD_BOTTOM = 48

local NOTE_WIDTH = 32
local NOTE_HEIGHT = 8
local GAP_WIDTH = 32

local BACK_COL = hex('141214')
local SEP_COL = hex('86898c')
local LANE_1_COL = hex('4fccff')
local LANE_2_COL = hex('ff9cf5')
local MEASURE_COL = hex('373138')

local SCROLL_SPEED = 60
local zoom = 1

function scale()
  return math.min(zoom, 1)
end

function getColumnX(i)
  if i < 4 then
    return -GAP_WIDTH/2 - NOTE_WIDTH * (3 - i + 0.5)
  else
    return GAP_WIDTH/2 + NOTE_WIDTH * (i - 3 - 0.5)
  end
end

function getColumnColor(i)
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

function getScrollSpeed()
  return SCROLL_SPEED * zoom
end
function beatToY(b)
  return love.graphics.getHeight() - PAD_BOTTOM - (b - conductor.getBeat()) * getScrollSpeed()
end
function yToBeat(y)
  return (love.graphics.getHeight() - PAD_BOTTOM - y) / getScrollSpeed() + conductor.getBeat()
end

function getLeft()
  return (-GAP_WIDTH/2 - NOTE_WIDTH * 3) * scale()
end
function getRight()
  return -getLeft()
end
function getMLeft()
  return -GAP_WIDTH/2 * scale()
end
function getMRight()
  return -getMLeft()
end

function openChart()
  local filepath = nfd.open('xdrv')

  if not filepath then return end

  local file, err = io.open(filepath, 'r')
  if not file then
    print(err)
    return
  end
  local data = file:read('*a')
  file:close()

  chart = xdrv.deserialize(data)
  chartDir = string.gsub(filepath, '([/\\])[^/\\]+$', '%1')
  conductor.loadFromChart(chart, chartDir)
end

function saveChart()
  if not chart then return end

  local filepath = nfd.save('xdrv', chartDir .. '/' .. chart.metadata.CHART_DIFFICULTY .. '.xdrv')

  if not filepath then return end

  local file, err = io.open(filepath, 'w')
  if not file then
    print(err)
    return
  end
  file:write('// Made with trackmaker v' .. release.version .. '\n' .. xdrv.serialize(chart))
  file:close()
end

function love.load()
  openChart()
end

function love.draw()
  sw, sh = love.graphics.getDimensions()
  scx, scy = sw/2, sh/2

  if not chart then
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf('No chart opened... (click to open)', 0, scy, sw, 'center')
    return
  end

  love.graphics.push()
  love.graphics.translate(scx, 0)

  love.graphics.setColor(BACK_COL:unpack())
  love.graphics.rectangle('fill', getLeft(), 0, getMLeft() - getLeft(), sh)
  love.graphics.rectangle('fill', getMRight(), 0, getRight() - getMRight(), sh)

  local topB = yToBeat(0)
  local botB = yToBeat(sh)
  local measureSize = 4
  local topM = math.ceil(topB / measureSize) * measureSize
  local botM = math.floor(botB / measureSize) * measureSize

  love.graphics.setLineWidth(1 * scale())
  love.graphics.setColor(MEASURE_COL:unpack())
  for b = botM, topM, measureSize do
    local y = beatToY(b)
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

  love.graphics.setLineWidth(5 * scale())
  love.graphics.setColor(LANE_1_COL:unpack())
  love.graphics.line(getLeft(), sh - PAD_BOTTOM, getMLeft(), sh - PAD_BOTTOM)
  love.graphics.setColor(LANE_2_COL:unpack())
  love.graphics.line(getRight(), sh - PAD_BOTTOM, getMRight(), sh - PAD_BOTTOM)

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

      love.graphics.setLineWidth(3 * scale())

      love.graphics.setColor(color:alpha(0.3):unpack())
      love.graphics.rectangle('fill', (GAP_WIDTH/2) * offset * scale(), yEnd, NOTE_WIDTH * 3 * offset * scale(), y - yEnd)
      love.graphics.setColor(color:unpack())
      love.graphics.line(getRight() * offset, y, getMRight() * offset, y)
      love.graphics.line(getRight() * offset, yEnd, getMRight() * offset, yEnd)
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

  love.graphics.pop()

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(
    'FPS ' .. love.timer.getFPS() .. '\n' ..
    'b: ' .. conductor.getBeat() .. '\n' ..
    '\n' ..
    chart.metadata.MUSIC_TITLE .. '\n' ..
    chart.metadata.MUSIC_ARTIST .. '\n' ..
    chart.metadata.CHART_AUTHOR
  )
end

function love.mousepressed(x, y, button)
  if button == 1 and not chart then
    openChart()
  end
end
function love.keypressed(key)
  if key == 'space' then
    if conductor.isPlaying() then
      conductor.pause()
    else
      conductor.play()
    end
  elseif key == 'down' then
    conductor.seekDelta(-conductor.beatsToSeconds(1))
  elseif key == 'up' then
    conductor.seekDelta(conductor.beatsToSeconds(1))
  elseif key == 's' and love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    saveChart()
  end
end
function love.wheelmoved(ox, oy)
  if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    zoom = zoom * (1 + math.max(math.min(oy / 15, 0.5), -0.5))
  else
    conductor.seekDelta(oy * 0.7 / zoom)
  end
end