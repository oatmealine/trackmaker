local self = {}

local deep = require 'lib.deep'

local waveform   = require 'src.waveform'
local conductor  = require 'src.conductor'
local xdrv       = require 'lib.xdrv'
local edit       = require 'src.edit'
local logs       = require 'src.logs'
local xdrvColors = require 'src.xdrvcolors'
local config     = require 'src.config'

local CheckpointPromptWidget = require 'src.widgets.checkpointprompt'

local layer = deep:new()

local PAD_BOTTOM = 256

local NOTE_WIDTH = 48
local NOTE_HEIGHT = 12
local GAP_WIDTH = 48

local BACK_COL = hex('141214')
local SEP_COL = hex('86898c')
local MEASURE_COL = hex('373138')

local selectionX, selectionY

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

local function getLaneColor(i)
  if i == xdrv.XDRVLane.Left then
    return xdrvColors.scheme.colors.LeftGear
  end
  return xdrvColors.scheme.colors.RightGear
end
self.getLaneColor = getLaneColor

local function getColumnColor(i)
  if i == 1 then
    return xdrvColors.scheme.colors.Column1
  elseif i == 2 then
    return xdrvColors.scheme.colors.Column2
  elseif i == 3 then
    return xdrvColors.scheme.colors.Column3
  elseif i == 4 then
    return xdrvColors.scheme.colors.Column4
  elseif i == 5 then
    return xdrvColors.scheme.colors.Column5
  elseif i == 6 then
    return xdrvColors.scheme.colors.Column6
  end
  return xdrvColors.scheme.colors.Column1
end
self.getColumnColor = getColumnColor

local function beatToY(b)
  return love.graphics.getHeight() - PAD_BOTTOM - (b - conductor.beat) * getScrollSpeed()
end
self.beatToY = beatToY
local function yToBeat(y)
  return (love.graphics.getHeight() - PAD_BOTTOM - y) / getScrollSpeed() + conductor.beat
end
self.yToBeat = yToBeat

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

local function drawNote(event)
  local note = event.note
  local x = getColumnX(note.column) * scale()
  local y = beatToY(event.beat)

  local width = NOTE_WIDTH * scale() * 0.95

  if y < -NOTE_HEIGHT then return -1 end
  if y > (sh + NOTE_HEIGHT) then return end

  love.graphics.setColor(getColumnColor(note.column):unpack())
  love.graphics.rectangle('fill', x - width/2, y - (NOTE_HEIGHT/2) * scale(), width, NOTE_HEIGHT * scale(), 1, 1)
end
local function drawHoldTail(event)
  local note = event.note
  if not note.length then return end

  local x = getColumnX(note.column) * scale()
  local y = beatToY(event.beat)
  local yEnd = beatToY(event.beat + (note.length or 0))

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  love.graphics.setColor((getColumnColor(note.column) * 0.5):unpack())
  local width = NOTE_WIDTH * scale() * 0.95 * 0.9
  love.graphics.rectangle('fill', x - width/2, yEnd, width, y - yEnd)
end

local checkTex = love.graphics.newImage('assets/sprites/check.png')

---@param event XDRVEvent
local function drawCheckpoint(event)
  local check = event.checkpoint

  local y = beatToY(event.beat)

  if y < -64 then return -1 end
  if y > (sh + 64) then return end

  local size = 12 / checkTex:getHeight() * scale()
  local x = (-GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52) * scale()
  local width = size * checkTex:getWidth()
  love.graphics.setColor(1, 1, 1, check and 1 or 0.5)
  love.graphics.draw(checkTex, x, y, 0, size, size, checkTex:getWidth(), checkTex:getHeight()/2)
  if check then
    love.graphics.setFont(fonts.inter_16)
    love.graphics.printf(check, math.floor(x - 8 - width - 256), math.floor(y - fonts.inter_16:getHeight()/2 + 8), 256, 'right')
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setFont(fonts.inter_12)
    love.graphics.printf('Checkpoint', math.floor(x - 8 - width - 256), math.floor(y - fonts.inter_12:getHeight()/2 - 8), 256, 'right')
  end
end

local gradMesh = love.graphics.newMesh({
  { 0,    0, 0, 0, 1, 1, 1, 1 },
  { 0,    1, 0, 0, 1, 1, 1, 1 },
  { 0.2,  0, 0, 0, 1, 1, 1, 0 },
  { 0.2,  1, 0, 0, 1, 1, 1, 0 },
  { 0.8,  0, 0, 0, 1, 1, 1, 0 },
  { 0.8,  1, 0, 0, 1, 1, 1, 0 },
  { 1,    0, 0, 0, 1, 1, 1, 1 },
  { 1,    1, 0, 0, 1, 1, 1, 1 },
}, 'strip', 'static')

local function drawGearShift(event)
  local gear = event.gearShift

  local color = getLaneColor(gear.lane)
  local offset = 1
  if gear.lane == xdrv.XDRVLane.Left then
    offset = -1
  end

  local y = beatToY(event.beat)
  local yEnd = beatToY(event.beat + gear.length)

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  local x = (GAP_WIDTH/2) * offset * scale()
  local width = NOTE_WIDTH * 3 * offset * scale()

  love.graphics.setColor(color:alpha(0.3):unpack())
  love.graphics.draw(gradMesh, x, yEnd, 0, width, y - yEnd)
  love.graphics.setColor(color:alpha(0.05):unpack())
  love.graphics.rectangle('fill', x, yEnd, width, y - yEnd)
end

local function drawGearShiftEnds(event)
  local gear = event.gearShift

  local color
  local offset = 1
  if gear.lane == xdrv.XDRVLane.Left then
    color = xdrvColors.scheme.colors.LeftGear
    offset = -1
  else
    color = xdrvColors.scheme.colors.RightGear
  end

  local y = beatToY(event.beat)
  local yEnd = beatToY(event.beat + gear.length)

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  love.graphics.setLineWidth(6 * scale())

  love.graphics.setColor(color:alpha(0.8):unpack())
  love.graphics.line(getRight() * offset, y, getMRight() * offset, y)
  love.graphics.line(getRight() * offset, yEnd, getMRight() * offset, yEnd)
end

local driftTex = love.graphics.newImage('assets/sprites/driftMarker.png')
local DRIFT_SPACING = 1

---@param dir XDRVDriftDirection
local function driftX(dir)
  if dir == xdrv.XDRVDriftDirection.Left    then return -1 end
  if dir == xdrv.XDRVDriftDirection.Right   then return 1  end
  return 0
end

-- all of this is Quite Janky, but oh well
-- with the way drifts are handled in the events table it's hard to do better
local function drawDrift(event, prevEvent)
  local dir = event.drift.direction
  local lastDir = prevEvent and prevEvent.drift.direction or xdrv.XDRVDriftDirection.Neutral

  local side
  if dir == xdrv.XDRVDriftDirection.Neutral then
    side = lastDir == xdrv.XDRVDriftDirection.Left and -1 or 1
  else
    side = dir == xdrv.XDRVDriftDirection.Left and -1 or 1
  end

  local baseX = (getMRight() + NOTE_WIDTH * 1.5) * scale()

  local startBeat
  local endBeat
  if dir == xdrv.XDRVDriftDirection.Neutral then
    startBeat = event.beat
    endBeat = conductor.beatAtTime(conductor.timeAtBeat(event.beat) + 1.5)
  else
    endBeat = conductor.beatAtTime(conductor.timeAtBeat(event.beat) - 1.5)
    startBeat = event.beat
  end

  local size = 32 * scale()

  local spacing = DRIFT_SPACING
  if startBeat > endBeat then
    spacing = -spacing
  end

  for b = startBeat, endBeat, spacing do
    local a = (b - startBeat) / (endBeat - startBeat)
    local dirDelta = a
    if startBeat > endBeat then
      dirDelta = 1 - a
    end
    local d = mix(driftX(lastDir), driftX(dir), dirDelta)
    local y = beatToY(b)
    love.graphics.setColor(1, 1, 1, (1 - a) * 0.4)
    for x = -baseX, baseX, baseX*2 do
      love.graphics.draw(driftTex, x + d * NOTE_WIDTH * scale(), y, 0, size / driftTex:getWidth(), size / driftTex:getHeight(), driftTex:getWidth()/2, driftTex:getHeight()/2)
    end
  end

  if lastDir ~= xdrv.XDRVDriftDirection.Neutral and prevEvent then
    for b = prevEvent.beat + DRIFT_SPACING, startBeat - DRIFT_SPACING, DRIFT_SPACING do
      local y = beatToY(b)
      love.graphics.setColor(1, 1, 1, 0.4)
      for x = -baseX, baseX, baseX*2 do
        love.graphics.draw(driftTex, x + driftX(lastDir) * NOTE_WIDTH * scale(), y, 0, size / driftTex:getWidth(), size / driftTex:getHeight(), driftTex:getWidth()/2, driftTex:getHeight()/2)
      end
    end
  end

  local col = rgb(1, 1, 1)
  if dir == xdrv.XDRVDriftDirection.Left then
    col = xdrvColors.scheme.colors.LeftGear
  elseif dir == xdrv.XDRVDriftDirection.Right then
    col = xdrvColors.scheme.colors.RightGear
  end

  love.graphics.setColor(col:unpack())
  love.graphics.setLineWidth(1 * scale())
  local y = beatToY(event.beat)
  local leftX = baseX * side - NOTE_WIDTH * 1.5 * scale()
  local rightX = baseX * side + NOTE_WIDTH * 1.5 * scale()
  for x = leftX, rightX, 15 do
    love.graphics.line(x, y, math.min(x + 7, rightX), y)
  end

  --[[
  local t = 'x'
  if dir == xdrv.XDRVDriftDirection.Left then
    t = '<'
  elseif dir == xdrv.XDRVDriftDirection.Right then
    t = '>'
  end
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.setFont(fonts.inter_16)
  love.graphics.print('DRIFT: ' .. t, getRight() + 32, round(y - fonts.inter_16:getHeight()/2))

  love.graphics.setColor(0.4, 0.4, 0.4, 1)
  love.graphics.setFont(fonts.inter_12)
  love.graphics.print('placeholder placeholder boooooo', getRight() + 32, round(y + 12))
  ]]
end

local QUANT_DEFAULT_COLOR = hex('a5a5a5')
local QUANT_COLORS = {
  hex('f15858'),
  hex('5671e8'),
  hex('ad66d4'),
  hex('f5db41'),
  nil,
  hex('f486ae'),
  hex('f19848'),
  hex('92f1ea'),
  hex('89ee7d'),
  nil,
  nil,
}

local function canPlaceCheckpoint(x, y)
  if x > (sw/2 - GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52) or x < (sw/2 - GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52 - 32) then return end

  local closest = quantize(yToBeat(y), edit.quantIndex)
  local closestY = beatToY(closest)

  if math.abs(closestY - y) > 32 then return end

  return closest
end

function self.draw()
  sw, sh = love.graphics.getDimensions()
  scx, scy = sw/2, sh/2

  if not chart.loaded then
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf('No chart opened... (' .. keybinds.formatBind(keybinds.binds.open) .. ' to open)', 0, scy, sw, 'center')
    return
  end

  love.graphics.push()
  love.graphics.translate(scx, 0)

  love.graphics.setColor(BACK_COL:unpack())
  love.graphics.rectangle('fill', getLeft(), 0, getMLeft() - getLeft(), sh)
  love.graphics.rectangle('fill', getMRight(), 0, getRight() - getMRight(), sh)

  local topB = math.ceil(yToBeat(0)) + 1
  local botB = math.floor(yToBeat(sh)) - 1

  love.graphics.setLineWidth(4 * scale())
  for b = botB, topB do
    local y = beatToY(b)
    local measure = conductor.getMeasure(b)

    if measure % 1 == 0 then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(tostring(measure), getRight() + 4, y - fonts.inter_12:getHeight()/2)

      love.graphics.setColor(MEASURE_COL:unpack())
    elseif measure % 1 == 0.5 then
      love.graphics.setColor(MEASURE_COL:alpha(0.5):unpack())
    else
      love.graphics.setColor(0, 0, 0, 0)
    end

    love.graphics.line(getLeft(), y, getMLeft(), y)
    love.graphics.line(getRight(), y, getMRight(), y)
  end

  love.graphics.setLineWidth(1 * scale())

  love.graphics.setColor(SEP_COL:unpack())
  for o = -1, 1, 2 do
    for i = 1, 2 do
      local x = o * (GAP_WIDTH/2 + NOTE_WIDTH * i) * scale()
      love.graphics.line(x, 0, x, sh)
    end
  end

  local sideW = 4 * scale()
  love.graphics.setLineWidth(sideW)

  love.graphics.setColor(xdrvColors.scheme.colors.LeftGear:alpha(0.5):unpack())
  love.graphics.line(getLeft() - sideW/2, sh, getLeft() - sideW/2, 0)
  love.graphics.line(getMLeft() + sideW/2, sh, getMLeft() + sideW/2, 0)
  love.graphics.setColor(xdrvColors.scheme.colors.RightGear:alpha(0.5):unpack())
  love.graphics.line(getRight() + sideW/2, sh, getRight() + sideW/2, 0)
  love.graphics.line(getMRight() - sideW/2, sh, getMRight() - sideW/2, 0)

  love.graphics.push()
  love.graphics.origin()
  if waveform.meshes and config.config.waveform then
    local totalHeight = waveform.totalHeight

    local width = NOTE_WIDTH * 3
    local offset = conductor.secondsToBeats(conductor.offset, conductor.bpms[1][2])
    local y0 = beatToY(0 + offset)
    local yEnd = beatToY(conductor.beatAtTime(totalHeight) + offset)

    local segmentSize = totalHeight / #waveform.meshes
    local waveHeight = segmentSize / totalHeight * (y0 - yEnd)

    local bri = config.config.waveformBrightness
    love.graphics.setColor(bri, bri, bri, config.config.waveformOpacity)

    for i, wav in ipairs(waveform.meshes) do
      local y = y0 - ((i - 1) * waveHeight)

      if y < 0 then break end
      if y < (sh + waveHeight) then
        for channel = 1, 2 do
          local mult = (channel - 1) * 2 - 1
          love.graphics.draw(wav[channel] or wav[1], sw/2 + getMRight() * mult, y, 0, (width * scale()) * mult, -waveHeight)
        end
      end
    end
  end
  love.graphics.pop()

  local events = chart.chart

  local lastDrift
  for _, event in ipairs(events) do
    if event.gearShift then
      layer:queue(1, drawGearShift, event)
      layer:queue(7, drawGearShiftEnds, event)
    end
    if event.note then
      layer:queue(3, drawHoldTail, event)
      layer:queue(4, drawNote, event)
    end
    if event.drift then
      layer:queue(0, drawDrift, event, lastDrift)
      lastDrift = event
    end
    if event.checkpoint then
      layer:queue(9, drawCheckpoint, event)
    end
  end

  for _, ghost in ipairs(edit.getGhosts()) do
    if ghost.note then
      layer:queue(5, drawHoldTail, ghost)
      layer:queue(6, drawNote, ghost)
    end
    if ghost.gearShift then
      layer:queue(2, drawGearShift, ghost)
      layer:queue(8, drawGearShiftEnds, ghost)
    end
  end

  layer:draw()

  local checkBeat = canPlaceCheckpoint(love.mouse.getPosition())
  if checkBeat then
    drawCheckpoint({ beat = checkBeat })
  end

  if config.config.renderInvalidEvents then
    local lastBeat
    local concBeats = 0
    for _, event in ipairs(events) do
      if not (event.note or event.gearShift or event.drift or event.checkpoint) then
        local x = (GAP_WIDTH/2 + NOTE_WIDTH * 3) * scale()
        local y = beatToY(event.beat)

        if y < 0 then break end
        if y < sh then
          local type = getEventType(event)

          if lastBeat ~= event.beat then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setLineWidth(1)
            love.graphics.line(x + 6, y, x + 18, y)
            concBeats = 0
          else
            concBeats = concBeats + 1
            y = y + 14 * concBeats

            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.line(x + 14, y, x + 18, y)
          end
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.print(string.format('%s : %s', type, string.gsub(pretty(event[type]), '\n', '')), x + 22, math.floor(y - 8))

          lastBeat = event.beat
        end
      end
    end
  end

  love.graphics.setLineWidth(5 * scale())
  love.graphics.setColor(xdrvColors.scheme.colors.LeftGear:unpack())
  love.graphics.line(getLeft(), sh - PAD_BOTTOM, getMLeft(), sh - PAD_BOTTOM)
  love.graphics.setColor(xdrvColors.scheme.colors.RightGear:unpack())
  love.graphics.line(getRight(), sh - PAD_BOTTOM, getMRight(), sh - PAD_BOTTOM)

  love.graphics.setLineWidth(1)

  local quantCol = QUANT_COLORS[edit.quantIndex]

  love.graphics.setColor((quantCol or QUANT_DEFAULT_COLOR):unpack())
  love.graphics.polygon('fill',
    getLeft() - 15, sh - PAD_BOTTOM,
    getLeft() - 30, sh - PAD_BOTTOM - 15,
    getLeft() - 45, sh - PAD_BOTTOM,
    getLeft() - 30, sh - PAD_BOTTOM + 15
  )
  love.graphics.polygon('fill',
    getRight() + 15, sh - PAD_BOTTOM,
    getRight() + 30, sh - PAD_BOTTOM - 15,
    getRight() + 45, sh - PAD_BOTTOM,
    getRight() + 30, sh - PAD_BOTTOM + 15
  )

  if not quantCol then
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.printf(tostring(getDivision(edit.quantIndex)), getLeft() - 45, sh - PAD_BOTTOM - fonts.inter_12:getHeight()/2, 30, 'center')
    love.graphics.printf(tostring(getDivision(edit.quantIndex)), getRight() + 15, sh - PAD_BOTTOM - fonts.inter_12:getHeight()/2, 30, 'center')
  end

  love.graphics.setLineWidth(1)

  for _, event in ipairs(edit.selection) do
    if event.note then
      local note = event.note
      local x = getColumnX(note.column) * scale()
      local y = beatToY(event.beat)
      local size = NOTE_WIDTH * scale()
      love.graphics.setColor(1, 1, 1, 0.3 + math.sin(love.timer.getTime() * 3) * 0.1)
      love.graphics.rectangle('fill', x - size/2, y - size/2, size, size)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle('line', x - size/2, y - size/2, size, size)
    end
    if event.gearShift then
      local gear = event.gearShift

      local x = ((gear.lane == xdrv.XDRVLane.Left) and getLeft() or getMRight())
      local y = beatToY(event.beat)
      local yEnd = beatToY(event.beat + gear.length)

      love.graphics.setColor(1, 1, 1, 0.3 + math.sin(love.timer.getTime() * 3) * 0.1)
      love.graphics.rectangle('fill', x, y, NOTE_WIDTH * 3 * scale(), yEnd - y)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle('line', x, y, NOTE_WIDTH * 3 * scale(), yEnd - y)
    end
  end

  love.graphics.pop()

  if waveform.status then
    love.graphics.setColor(1, 1, 1, 0.8)
    -- slightly wacky, but it's ok
    local w = fonts.inter_12:getWidth(waveform.status)
    love.graphics.printf(waveform.status, 0, sh - 100, sw, 'center')
    love.graphics.rectangle('fill', sw/2 - w/2, sh - 100 + fonts.inter_12:getHeight() + 1, w * waveform.progress, 2)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle('fill', sw/2 - w/2, sh - 100 + fonts.inter_12:getHeight() + 1, w, 2)
  end

  if selectionX and selectionY then
    local mx, my = love.mouse.getPosition()
    local x1, y1, x2, y2 = math.min(selectionX, mx), math.min(selectionY, my), math.max(selectionX, mx), math.max(selectionY, my)

    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle('fill', x1, y1, x2 - x1, y2 - y1)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle('line', x1, y1, x2 - x1, y2 - y1)
  end
end

function self.mousepressed(x, y, button)
  local check = canPlaceCheckpoint(x, y)
  if button == 1 and check then
    local name
    local existingCheckpoint = chart.findEventOfType(check, 'checkpoint')
    if existingCheckpoint then
      name = chart.chart[existingCheckpoint].checkpoint
    end

    openWidget(CheckpointPromptWidget(check, name), true)
    return
  end

  if not edit.write and button == 1 and chart.loaded then
    selectionX, selectionY = x, y
    return
  end
end
function self.mousereleased(x, y, button)
  if button == 1 and selectionX and selectionY then
    local x1, y1, x2, y2 = math.min(selectionX, x), math.min(selectionY, y), math.max(selectionX, x), math.max(selectionY, y)
    selectionX, selectionY = nil, nil

    if math.abs(x2 - x1) < 4 and math.abs(y2 - y1) < 4 then
      if #edit.selection > 0 then
        edit.clearSelection()
        logs.log('Cleared selection')
      end
      return
    end

    local selected = {}

    for _, event in ipairs(chart.chart) do
      if event.note then
        local note = event.note
        local x = getColumnX(note.column) * scale() + scx
        local y = beatToY(event.beat)
        local yEnd = beatToY(event.beat + (note.length or 0))

        if x >= x1 and x <= x2 and math.min(y, yEnd) >= y1 and math.max(y, yEnd) <= y2 then
          table.insert(selected, event)
        end
      end
      if event.gearShift then
        local gear = event.gearShift

        local x = ((gear.lane == xdrv.XDRVLane.Left) and (getLeft() + getMLeft())/2 or (getRight() + getMRight())/2) + scx
        local y = beatToY(event.beat)
        local yEnd = beatToY(event.beat + gear.length)

        if x >= x1 and x <= x2 and math.min(y, yEnd) >= y1 and math.max(y, yEnd) <= y2 then
          table.insert(selected, event)
        end
      end
    end

    if love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift') then
      local n = 0
      for _, e in ipairs(selected) do
        if not includes(edit.selection, e) then
          table.insert(edit.selection, e)
          n = n + 1
        end
      end
      logs.log('Selected +' .. n .. ' events')
    elseif #selected == 0 then
      if #edit.selection > 0 then
        edit.clearSelection()
        logs.log('Cleared selection')
      end
    else
      edit.clearSelection()
      edit.selection = selected
      logs.log('Selected ' .. #selected .. ' events')
    end
  end
end

function self.wheelmoved(delta)
  if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    zoom = zoom * (1 + math.max(math.min(delta / 12, 0.5), -0.5))
  else
    conductor.seekBeats(conductor.beat + sign(delta) * QUANTS[edit.quantIndex])
    edit.updateGhosts()
    conductor.initStates()
  end
end

return self