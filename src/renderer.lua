local self = {}

local deep = require 'lib.deep'
local easable = require 'lib.easable'
local cpml = require 'lib.cpml'

local preview    = require 'src.preview'
local waveform   = require 'src.waveform'
local conductor  = require 'src.conductor'
local xdrv       = require 'lib.xdrv'
local edit       = require 'src.edit'
local logs       = require 'src.logs'
local xdrvColors = require 'src.xdrvcolors'
local config     = require 'src.config'

local CheckpointPromptWidget = require 'src.widgets.checkpointprompt'

local layer = deep:new()

local BASE_SCALE = 55
local NOTE_WIDTH = (3.336 * 0.25) * BASE_SCALE
local NOTE_HEIGHT = NOTE_WIDTH * (0.25 / 0.75)
local GAP_WIDTH = (4 * BASE_SCALE - NOTE_WIDTH * 1.5)/2

local CANVAS_PAD = 16 -- on each side
local canvas3d = love.graphics.newCanvas(CANVAS_PAD * 2 + NOTE_WIDTH * 6 + GAP_WIDTH, love.graphics.getHeight() * 4)

local function getPadBottom()
  if config.config.previewMode then
    return canvas3d:getHeight()/2 - 4 * BASE_SCALE
  else
    return 200
  end
end


local BACK_COL = hex('131313')
local SEP_COL = hex('86898c')
local MEASURE_COL = hex('373138')

local selectionX, selectionY

local zoom = 1

local SCROLL_SPEED = 60
local cachedScrollSpeed = 1

local function getScrollSpeed()
  return SCROLL_SPEED * zoom * cachedScrollSpeed
end

local function scale()
  if config.config.previewMode then return 1 end
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

---@param b number
---@param sh number?
local function beatToY(b, sh)
  if config.config.cmod then
    return (sh or love.graphics.getHeight()) - getPadBottom() - (conductor.timeAtBeat(b) - conductor.time) * getScrollSpeed()
  else
    return (sh or love.graphics.getHeight()) - getPadBottom() - (b - conductor.beat) * getScrollSpeed()
  end
end
self.beatToY = beatToY
---@param y number
---@param sh number?
local function yToBeat(y, sh)
  if config.config.cmod then
    return conductor.beatAtTime(((sh or love.graphics.getHeight()) - getPadBottom() - y) / getScrollSpeed()) + conductor.beat
  else
    return ((sh or love.graphics.getHeight()) - getPadBottom() - y) / getScrollSpeed() + conductor.beat
  end
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

local function drawNote(thing, sh)
  if config.config.previewMode and thing.beat < conductor.beat then return end

  local note = thing.note
  local x = getColumnX(note.column) * scale()
  local y = beatToY(thing.beat, sh)

  local width = NOTE_WIDTH * scale() * 0.95

  if y < -NOTE_HEIGHT then return -1 end
  if y > (sh + NOTE_HEIGHT) then return end

  love.graphics.setColor(getColumnColor(note.column):unpack())
  love.graphics.rectangle('fill', x - width/2, y - (NOTE_HEIGHT/2) * scale(), width, NOTE_HEIGHT * scale(), 1, 1)
end
local function drawHoldTail(thing, sh)
  local note = thing.note
  if not note.length then return end

  if config.config.previewMode and (thing.beat + note.length) < conductor.beat then return end

  local startBeat = thing.beat

  if config.config.previewMode then
    startBeat = math.max(thing.beat, conductor.beat)
  end

  local x = getColumnX(note.column) * scale()
  local y = beatToY(startBeat, sh)
  local yEnd = beatToY(thing.beat + (note.length or 0), sh)

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  love.graphics.setColor((getColumnColor(note.column) * 0.5):unpack())
  local width = NOTE_WIDTH * scale() * 0.95 * 0.9
  love.graphics.rectangle('fill', x - width/2, yEnd, width, y - yEnd)
end

local checkTex = love.graphics.newImage('assets/sprites/check.png')

local function canPlaceCheckpoint(x, y)
  if x > (love.graphics.getWidth()/2 - GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52) or x < (love.graphics.getWidth()/2 - GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52 - 32) then return end

  local closest = quantize(yToBeat(y), edit.quantIndex)
  local closestY = beatToY(closest)

  if math.abs(closestY - y) > 32 then return end

  return closest
end

local function getHoveredEvent()
  local x, y = love.mouse.getPosition()
  if x < (love.graphics.getWidth()/2 + GAP_WIDTH/2 + NOTE_WIDTH * 3 + 40) then return end

  local hoverBeat = yToBeat(y)

  local closestEvent
  local closestEventDist = 9e9

  for _, thing in ipairs(chart.chart) do
    if thing.beat - hoverBeat > 1.5 then break end
    if thing.beat - hoverBeat > -1.5 then
      local thingY = beatToY(thing.beat)
      local dist = math.abs(thingY - y)
      if dist < closestEventDist then
        closestEvent = thing
        closestEventDist = dist
      end
    end
  end

  if closestEventDist < 32 then
    return closestEvent.beat
  end

  local closest = quantize(hoverBeat, edit.quantIndex)
  local closestY = beatToY(closest)

  if math.abs(closestY - y) > 32 then return end

  return closest
end

---@param thing XDRVThing
---@param sh number
local function drawCheckpoint(thing, sh)
  local check = thing.checkpoint
  local checkBeat = canPlaceCheckpoint(love.mouse.getPosition())

  local y = beatToY(thing.beat, sh)

  local renderTransparent = (not check) or (checkBeat == thing.beat)

  if y < -64 then return -1 end
  if y > (sh + 64) then return end

  local size = 12 / checkTex:getHeight() * scale()
  local x = (-GAP_WIDTH/2 - NOTE_WIDTH * 3 - 52) * scale()
  local width = size * checkTex:getWidth()
  love.graphics.setColor(1, 1, 1, renderTransparent and 0.3 or 1)
  love.graphics.draw(checkTex, x, y, 0, size, size, checkTex:getWidth(), checkTex:getHeight()/2)
  if check then
    love.graphics.setColor(1, 1, 1, 1)
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

local function drawGearShift(thing, sh)
  local gear = thing.gearShift

  if config.config.previewMode and (thing.beat + gear.length) < conductor.beat then return end

  local color = getLaneColor(gear.lane)
  local offset = 1
  if gear.lane == xdrv.XDRVLane.Left then
    offset = -1
  end

  local startBeat = thing.beat

  if config.config.previewMode then
    startBeat = math.max(thing.beat, conductor.beat)
  end

  local y = beatToY(startBeat, sh)
  local yEnd = beatToY(thing.beat + gear.length, sh)

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  local x = (GAP_WIDTH/2) * offset * scale()
  local width = NOTE_WIDTH * 3 * offset * scale()

  love.graphics.setColor(color:alpha(0.3):unpack())
  love.graphics.draw(gradMesh, x, yEnd, 0, width, y - yEnd)
  love.graphics.setColor(color:alpha(0.05):unpack())
  love.graphics.rectangle('fill', x, yEnd, width, y - yEnd)
end

local function drawGearShiftEnds(thing, sh)
  local gear = thing.gearShift

  local color
  local offset = 1
  if gear.lane == xdrv.XDRVLane.Left then
    color = xdrvColors.scheme.colors.LeftGear
    offset = -1
  else
    color = xdrvColors.scheme.colors.RightGear
  end

  local y = beatToY(thing.beat, sh)
  local yEnd = beatToY(thing.beat + gear.length, sh)

  if math.max(y, yEnd) < -NOTE_HEIGHT then return -1 end
  if math.min(y, yEnd) > (sh + NOTE_HEIGHT) then return end

  love.graphics.setLineWidth(6 * scale())

  love.graphics.setColor(color:alpha(0.8):unpack())
  if not (config.config.previewMode and thing.beat < conductor.beat) then
    love.graphics.line(getRight() * offset, y, getMRight() * offset, y)
  end
  if not (config.config.previewMode and (thing.beat + gear.length) < conductor.beat) then
    love.graphics.line(getRight() * offset, yEnd, getMRight() * offset, yEnd)
  end
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
-- with the way drifts are handled in the things table it's hard to do better
local function drawDrift(thing, prevEvent, sh)
  local dir = thing.drift.direction
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
    startBeat = thing.beat
    endBeat = conductor.beatAtTime(conductor.timeAtBeat(thing.beat) + 1.5)
  else
    endBeat = conductor.beatAtTime(conductor.timeAtBeat(thing.beat) - 1.5)
    startBeat = thing.beat
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
    local y = beatToY(b, sh)
    if not (config.config.previewMode and conductor.beat > b) then
      love.graphics.setColor(1, 1, 1, (1 - a) * 0.4)
      for x = -baseX, baseX, baseX*2 do
        love.graphics.draw(driftTex, x + d * NOTE_WIDTH * scale(), y, 0, size / driftTex:getWidth(), size / driftTex:getHeight(), driftTex:getWidth()/2, driftTex:getHeight()/2)
      end
    end
  end

  if lastDir ~= xdrv.XDRVDriftDirection.Neutral and prevEvent then
    for b = prevEvent.beat + DRIFT_SPACING, startBeat - DRIFT_SPACING, DRIFT_SPACING do
      local y = beatToY(b, sh)
      if not (config.config.previewMode and conductor.beat > b) then
        love.graphics.setColor(1, 1, 1, 0.4)
        for x = -baseX, baseX, baseX*2 do
          love.graphics.draw(driftTex, x + driftX(lastDir) * NOTE_WIDTH * scale(), y, 0, size / driftTex:getWidth(), size / driftTex:getHeight(), driftTex:getWidth()/2, driftTex:getHeight()/2)
        end
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
  local y = beatToY(thing.beat, sh)
  if not (config.config.previewMode and conductor.beat > thing.beat) then
    local leftX = baseX * side - NOTE_WIDTH * 1.5 * scale()
    local rightX = baseX * side + NOTE_WIDTH * 1.5 * scale()
    for x = leftX, rightX, 15 do
      love.graphics.line(x, y, math.min(x + 7, rightX), y)
    end
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

local laneGradMesh = love.graphics.newMesh({
  { 0,    0, 0, 0, 1, 1, 1, 0 },
  { 1,    0, 0, 0, 1, 1, 1, 0 },
  { 0,    1, 0, 0, 1, 1, 1, 1 },
  { 1,    1, 0, 0, 1, 1, 1, 1 },
}, 'strip', 'static')

---@type easable[]
local laneActive = {}
for i = 1, 6 do
  laneActive[i] = easable(0, 16)
end

local mesh3d = love.graphics.newMesh({
  {'VertexPosition', 'float', 3}, -- introduce Z axis
  {'VertexTexCoord', 'float', 2}, -- UVs
  -- ignore color
}, {
  -- x, y, z, u, v
  {-0.5, -0.5,  0, 0, 1},
  { 0.5, -0.5,  0, 1, 1},
  {-0.5,  0.5,  0, 0, 0},
  { 0.5,  0.5,  0, 1, 0},
}, 'strip', 'static')
mesh3d:setTexture(canvas3d)

local vertShader = love.graphics.newShader([[
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
  return projectionMatrix * viewMatrix * modelMatrix * vertexPosition;
}
]])

local hoveredEventBeat

function self.draw()
  local sw, sh, scx, scy = screenCoords()

  for _, ease in ipairs(laneActive) do
    ease:update(love.timer.getDelta())
  end

  cachedScrollSpeed = preview.getScrollSpeed(conductor.beat)

  local noNotes = getScrollSpeed() == 0

  if not chart.loaded then
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf('No chart opened... (' .. keybinds.formatBind(keybinds.binds.open) .. ' to open)', 0, scy, sw, 'center')
    return
  end

  if not config.config.view.chart then
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf('You hid the chart. Congratulations?\nI\'m not sure what you were expecting to happen...', 0, scy, sw, 'center')
    return
  end

  hoveredEventBeat = getHoveredEvent()

  if config.config.previewMode then
    love.graphics.setCanvas(canvas3d)

    sw, sh = canvas3d:getDimensions()
    scx, scy = sw/2, sh/2

    love.graphics.clear(0, 0, 0, 0)
  end

  love.graphics.push()
  love.graphics.translate(scx, 0)

  love.graphics.setColor(BACK_COL:unpack())
  love.graphics.rectangle('fill', getLeft(), 0, getMLeft() - getLeft(), sh)
  love.graphics.rectangle('fill', getMRight(), 0, getRight() - getMRight(), sh)

  local padBottom = getPadBottom()

  for c = 1, 6 do
    local x = getColumnX(c)
    love.graphics.setColor(1, 1, 1, laneActive[c].eased * 0.45)
    love.graphics.draw(laneGradMesh, x - NOTE_WIDTH/2, 32, 0, NOTE_WIDTH, (sh - 32) - padBottom)
  end

  if not noNotes then
    local topB = math.ceil(yToBeat(0, sh)) + 1
    local botB = math.floor(yToBeat(sh, sh)) - 1
    if config.config.previewMode then
      botB = math.ceil(conductor.beat)
    end

    love.graphics.setLineWidth(4 * scale())

    local nextMeasureI = 1
    local nextMeasure = conductor.measures[1]

    while nextMeasure < botB do
      nextMeasureI = nextMeasureI + 1
      nextMeasure = conductor.measures[nextMeasureI]
    end

    for b = botB, topB do
      local y = beatToY(b, sh)

      love.graphics.setColor(0.6, 0.6, 0.6, 1)
      if b == nextMeasure then
        if not config.config.previewMode then
          love.graphics.print(tostring(nextMeasureI), math.floor(getRight() + 16), math.floor(y - fonts.inter_12:getHeight()/2))
        end
        nextMeasureI = nextMeasureI + 1
        nextMeasure = conductor.measures[nextMeasureI]
        love.graphics.setColor(MEASURE_COL:unpack())
      elseif not config.config.previewMode then
        love.graphics.setColor(MEASURE_COL:alpha(0.5):unpack())
      else
        love.graphics.setColor(0, 0, 0, 0)
      end

      love.graphics.line(getLeft(), y, getMLeft(), y)
      love.graphics.line(getRight(), y, getMRight(), y)
    end
  end

  love.graphics.setLineWidth(1 * scale())

  love.graphics.setColor(SEP_COL:unpack())
  for o = -1, 1, 2 do
    for i = 1, 2 do
      local x = o * (GAP_WIDTH/2 + NOTE_WIDTH * i) * scale()
      love.graphics.line(x, 0, x, sh)
    end
  end

  --print((12 * 0.25) * BASE_SCALE)
  --print((NOTE_WIDTH * 6 + GAP_WIDTH))

  local sideW = ((12 * 0.25) * BASE_SCALE * 2 - (NOTE_WIDTH * 6 + GAP_WIDTH)) * scale() / 2
  love.graphics.setLineWidth(sideW)

  love.graphics.setColor(xdrvColors.scheme.colors.LeftGear:alpha(0.5):unpack())
  love.graphics.line(getLeft() + sideW/2, sh, getLeft() + sideW/2, 0)
  love.graphics.line(getMLeft() - sideW/2, sh, getMLeft() - sideW/2, 0)
  love.graphics.setColor(xdrvColors.scheme.colors.RightGear:alpha(0.5):unpack())
  love.graphics.line(getRight() - sideW/2, sh, getRight() - sideW/2, 0)
  love.graphics.line(getMRight() + sideW/2, sh, getMRight() + sideW/2, 0)

  love.graphics.push()
  love.graphics.origin()
  if waveform.meshes and config.config.waveform and not noNotes and not config.config.previewMode then
    local totalHeight = waveform.totalHeight

    local width = NOTE_WIDTH * 3
    local offset = conductor.secondsToBeats(conductor.offset, conductor.bpms[1][2])
    local y0 = beatToY(0 + offset, sh)
    local yEnd = beatToY(conductor.beatAtTime(totalHeight) + offset, sh)

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

  if not noNotes then
    local things = chart.chart

    local lastDrift
    for _, thing in ipairs(things) do
      if thing.gearShift then
        layer:queue(1, drawGearShift, thing, sh)
        layer:queue(7, drawGearShiftEnds, thing, sh)
      end
      if thing.note then
        layer:queue(3, drawHoldTail, thing, sh)
        layer:queue(4, drawNote, thing, sh)
      end
      if thing.drift and config.config.view.drifts then
        layer:queue(0, drawDrift, thing, lastDrift, sh)
        lastDrift = thing
      end
      if thing.checkpoint and config.config.view.checkpoints and not config.config.previewMode then
        layer:queue(9, drawCheckpoint, thing, sh)
      end
    end

    for _, ghost in ipairs(edit.getGhosts()) do
      if ghost.note then
        layer:queue(5, drawHoldTail, ghost, sh)
        layer:queue(6, drawNote, ghost, sh)
      end
      if ghost.gearShift then
        layer:queue(2, drawGearShift, ghost, sh)
        layer:queue(8, drawGearShiftEnds, ghost, sh)
      end
    end

    layer:draw()

    local checkBeat = canPlaceCheckpoint(love.mouse.getPosition())
    if checkBeat and config.config.view.checkpoints and not config.config.previewMode then
      drawCheckpoint({ beat = checkBeat }, sh)
    end

    if not config.config.previewMode then
      love.graphics.setFont(fonts.inter_16)

      local lastBeat
      local lastX, lastY = 0, 0
      for _, thing in ipairs(things) do
        local hovered = thing.beat == hoveredEventBeat

        local x = (GAP_WIDTH/2 + NOTE_WIDTH * 3) * scale() + 50
        local y = beatToY(thing.beat, sh)

        if y < 0 then break end
        if y < sh then
          if lastBeat == thing.beat then
            if hovered then
              y = lastY + 16
            else
              x = lastX
            end
          end

          local col = rgb(1, 1, 1)
          local text

          if thing.bpm then
            col = rgb(0.6, 0.2, 0.2)
            text = string.format('%.3f', thing.bpm)
          elseif thing.warp then
            col = rgb(0.6, 0.2, 0.6)
            text = string.format('%.3f', thing.warp)
          elseif thing.stop then
            col = hex('bbd06c')
            text = string.format('%.3f', thing.stop)
          elseif thing.stopSeconds then
            col = hex('bbd06c')
            text = string.format('%.3fs', thing.stopSeconds)
          elseif not (thing.note or thing.gearShift or thing.drift or thing.checkpoint) and config.config.view.invalidEvents then
            local type = getThingType(thing)
            col = rgb(0.6, 0.1, 0.7)
            if hovered then
              text = string.format('%s : %s', type, string.gsub(pretty(thing[type]), '\n', ''))
            else
              text = type
            end
          end

          if hovered then
            col = col * 0.7
          end

          if text then
            love.graphics.setColor(col:unpack())
            local textWidth = fonts.inter_16:getWidth(text)
            love.graphics.rectangle('fill', x, y - 10, textWidth + 6, 20, 2, 2)
            love.graphics.polygon('fill', x - 6, y, x, y - 6, x, y + 6)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.print(text, math.floor(x + 3), math.floor(y - fonts.inter_16:getHeight()/2 - 2 + 2))
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(text, math.floor(x + 3), math.floor(y - fonts.inter_16:getHeight()/2 - 2))
            width = 3 + textWidth + 3 + 8

            lastBeat = thing.beat
            lastX, lastY = x + width, y
          end
        end
      end
    end
  end

  love.graphics.setFont(fonts.inter_12)

  love.graphics.setLineWidth(5 * scale())
  love.graphics.setColor(xdrvColors.scheme.colors.LeftGear:unpack())
  love.graphics.line(getLeft(), sh - padBottom, getMLeft(), sh - padBottom)
  love.graphics.setColor(xdrvColors.scheme.colors.RightGear:unpack())
  love.graphics.line(getRight(), sh - padBottom, getMRight(), sh - padBottom)

  love.graphics.setLineWidth(1)

  if not config.config.previewMode then
    local quantCol = QUANT_COLORS[edit.quantIndex]

    love.graphics.setColor((quantCol or QUANT_DEFAULT_COLOR):unpack())
    love.graphics.polygon('fill',
      getLeft() - 15, sh - padBottom,
      getLeft() - 30, sh - padBottom - 15,
      getLeft() - 45, sh - padBottom,
      getLeft() - 30, sh - padBottom + 15
    )
    love.graphics.polygon('fill',
      getRight() + 15, sh - padBottom,
      getRight() + 30, sh - padBottom - 15,
      getRight() + 45, sh - padBottom,
      getRight() + 30, sh - padBottom + 15
    )

    if not quantCol then
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.printf(tostring(getDivision(edit.quantIndex)), getLeft() - 45, sh - padBottom - fonts.inter_12:getHeight()/2, 30, 'center')
      love.graphics.printf(tostring(getDivision(edit.quantIndex)), getRight() + 15, sh - padBottom - fonts.inter_12:getHeight()/2, 30, 'center')
    end
  end

  love.graphics.setLineWidth(1)

  if not noNotes then
    for _, things in ipairs(edit.selection) do
      if things.note then
        local note = things.note
        local x = getColumnX(note.column) * scale()
        local y = beatToY(things.beat, sh)
        local size = NOTE_WIDTH * scale()
        love.graphics.setColor(1, 1, 1, 0.3 + math.sin(love.timer.getTime() * 3) * 0.1)
        love.graphics.rectangle('fill', x - size/2, y - size/2, size, size)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('line', x - size/2, y - size/2, size, size)
      end
      if things.gearShift then
        local gear = things.gearShift

        local x = ((gear.lane == xdrv.XDRVLane.Left) and getLeft() or getMRight())
        local y = beatToY(things.beat, sh)
        local yEnd = beatToY(things.beat + gear.length, sh)

        love.graphics.setColor(1, 1, 1, 0.3 + math.sin(love.timer.getTime() * 3) * 0.1)
        love.graphics.rectangle('fill', x, y, NOTE_WIDTH * 3 * scale(), yEnd - y)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle('line', x, y, NOTE_WIDTH * 3 * scale(), yEnd - y)
      end
    end
  end

  love.graphics.pop()

  love.graphics.setCanvas()

  sw, sh, scx, scy = screenCoords()

  if config.config.previewMode then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')

    love.graphics.push()
    love.graphics.origin()

    --love.graphics.setMeshCullMode('back')

    local ratio = canvas3d:getWidth() / canvas3d:getHeight()

    love.graphics.setShader(vertShader)

    local m = cpml.mat4()

    -- U = unity units
    local playfieldWidthU = (NOTE_WIDTH * 6 + GAP_WIDTH) / BASE_SCALE
    local canvasWidthU = playfieldWidthU - (CANVAS_PAD * 2) / BASE_SCALE

    local modelScale = canvasWidthU/2
    --local modelScale = 2

    m:scale(m, {x = modelScale, y = modelScale / (ratio * 3.4), z = 1})

    local v = cpml.mat4().from_direction(cpml.vec3(0, 0, -1), cpml.vec3(0, 1, 0))
    v:translate(m, cpml.vec3(0, 3.1, -4))
    v:rotate(v, math.rad(-(90 - 59)), cpml.vec3.unit_x)

    local p = cpml.mat4().from_perspective(100, love.graphics.getWidth() / love.graphics.getHeight(), 0.3, 1000.0)

    vertShader:send('modelMatrix', m:to_vec4s_cols())
    vertShader:send('viewMatrix', v:to_vec4s_cols())
    vertShader:send('projectionMatrix', p:to_vec4s_cols())
    love.graphics.draw(mesh3d)
    love.graphics.setShader()

    love.graphics.setMeshCullMode('none')
    love.graphics.setBlendMode('alpha', 'alphamultiply')

    love.graphics.pop()
  end

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

-- globals bc lua module resolution sucks
function laneHit(i)
  laneActive[i]:reset(1)
end
function laneRelease(i)
  laneActive[i]:set(0)
end

function self.mousepressed(x, y, button)
  if config.config.previewMode then return end
  if not config.config.view.chart then return end

  local check = canPlaceCheckpoint(x, y)
  if button == 1 and check and config.config.view.checkpoints then
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

    for _, thing in ipairs(chart.chart) do
      if thing.note then
        local note = thing.note
        local x = getColumnX(note.column) * scale() + love.graphics.getWidth()/2
        local y = beatToY(thing.beat)
        local yEnd = beatToY(thing.beat + (note.length or 0))

        if x >= x1 and x <= x2 and math.min(y, yEnd) >= y1 and math.max(y, yEnd) <= y2 then
          table.insert(selected, thing)
        end
      end
      if thing.gearShift then
        local gear = thing.gearShift

        local x = ((gear.lane == xdrv.XDRVLane.Left) and (getLeft() + getMLeft())/2 or (getRight() + getMRight())/2) + love.graphics.getWidth()/2
        local y = beatToY(thing.beat)
        local yEnd = beatToY(thing.beat + gear.length)

        if x >= x1 and x <= x2 and math.min(y, yEnd) >= y1 and math.max(y, yEnd) <= y2 then
          table.insert(selected, thing)
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
      logs.log('Selected +' .. n .. ' notes')
    elseif #selected == 0 then
      if #edit.selection > 0 then
        edit.clearSelection()
        logs.log('Cleared selection')
      end
    else
      edit.clearSelection()
      edit.selection = selected
      logs.log('Selected ' .. #selected .. ' notes')
    end
  end
end

function self.wheelmoved(delta)
  if love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    zoom = zoom * (1 + math.max(math.min(delta / 12, 0.5), -0.5))
  else
    edit.setBeat(conductor.beat + sign(delta) * QUANTS[edit.quantIndex])
    edit.updateGhosts()
    conductor.initStates()
  end
end

return self