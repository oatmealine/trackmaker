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
local EventEditWidget        = require 'src.widgets.eventedit'
local ContextWidget          = require 'src.widgets.context'

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


--local BACK_COL = hex('131313') -- now set with mods
local SEP_COL = hex('86898c')
local MEASURE_COL = hex('373138')

local selectionX, selectionY

local cachedScrollSpeed = 1

function self.getScrollSpeedRaw()
  return config.config.scrollSpeed
end

local function scale()
  if config.config.previewMode then return 1 end
  return math.min(self.getScrollSpeedRaw(), 0.5) * 2
end

local function getScrollSpeed()
  return self.getScrollSpeedRaw() * cachedScrollSpeed
end

local function getScaledScrollSpeed()
  return getScrollSpeed() / conductor.maxBPM * 200
end
self.getScaledScrollSpeed = getScaledScrollSpeed

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
    return (sh or love.graphics.getHeight()) - getPadBottom() - (conductor.timeAtBeat(b) - conductor.time) * getScaledScrollSpeed() * BASE_SCALE
  else
    return (sh or love.graphics.getHeight()) - getPadBottom() - (b - conductor.beat) * getScaledScrollSpeed() * BASE_SCALE
  end
end
self.beatToY = beatToY
---@param y number
---@param sh number?
local function yToBeat(y, sh)
  if config.config.cmod then
    return conductor.beatAtTime(((sh or love.graphics.getHeight()) - getPadBottom() - y) / getScaledScrollSpeed() / BASE_SCALE) + conductor.beat
  else
    return ((sh or love.graphics.getHeight()) - getPadBottom() - y) / getScaledScrollSpeed() / BASE_SCALE + conductor.beat
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
  local mx, my, mz = preview.getNotePos(note.column)
  local sx, sy, sz = preview.getNoteScale(note.column)
  local x = getColumnX(note.column) * scale() + mx * NOTE_WIDTH
  local y = beatToY(thing.beat, sh) + my * NOTE_WIDTH

  if y < -NOTE_HEIGHT then return -1 end
  if y > (sh + NOTE_HEIGHT) then return end

  if note.mine then
    love.graphics.setColor(getColumnColor(note.column):alpha(0.8):unpack())
    love.graphics.setLineWidth(6)
    local width = NOTE_WIDTH * scale() * sx * 0.6
    local height = NOTE_WIDTH * scale() * sy * 0.6
    love.graphics.ellipse('line', x, y, width/2, height/2)
    love.graphics.setLineWidth(1)
  else
    local width = NOTE_WIDTH * scale() * 0.95 * sx
    local height = NOTE_HEIGHT * sy

    love.graphics.setColor(getColumnColor(note.column):unpack())
    love.graphics.rectangle('fill', x - width/2, y - (height/2) * scale(), width, height * scale(), 1, 1)
  end
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

---@param thing XDRVThing
---@param sh number
local function drawCheckpoint(thing, sh)
  local check = thing.checkpoint
  local checkBeat = canPlaceCheckpoint(love.mouse.getPosition())

  local y = beatToY(thing.beat, sh)

  local renderTransparent = (not check) or beatCmp(checkBeat, thing.beat)

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

local gearshiftMesh = love.graphics.newMesh({
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
  love.graphics.draw(gearshiftMesh, x, yEnd, 0, width, y - yEnd)
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

local function drawMeasureLine(b, sh, alpha, lane)
  lane = lane or -1
  local y = beatToY(b, sh)

  love.graphics.setColor(MEASURE_COL:alpha(alpha or 1):unpack())
  if lane == xdrv.XDRVLane.Left or lane == -1 then
    love.graphics.line(getLeft(), y, getMLeft(), y)
  end
  if lane == xdrv.XDRVLane.Right or lane == -1 then
    love.graphics.line(getRight(), y, getMRight(), y)
  end
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

--  x  y  z  ?  r  g  b  a
local laneGradMesh = love.graphics.newMesh({
  { 0, 0, 0, 0, 1, 1, 1, 0 },
  { 1, 0, 0, 0, 1, 1, 1, 0 },
  { 0, 1, 0, 0, 1, 1, 1, 1 },
  { 1, 1, 0, 0, 1, 1, 1, 1 },
}, 'strip', 'static')

--  x  y  z  ?  r  g  b  a
local lightsGradMesh = love.graphics.newMesh({
  { 0, 0, 0, 0, 1, 1, 1, 1 },
  { 1, 0, 0, 0, 1, 1, 1, 0 },
  { 0, 1, 0, 0, 1, 1, 1, 1 },
  { 1, 1, 0, 0, 1, 1, 1, 0 },
}, 'strip', 'static')

---@type easable[]
local laneActive = {}
for i = 1, 6 do
  laneActive[i] = easable(0, 16)
end

local laneMeshLeft = love.graphics.newMesh({
  {'VertexPosition', 'float', 3}, -- introduce Z axis
  {'VertexTexCoord', 'float', 2}, -- UVs
  -- ignore color
}, {
  -- x, y, z, u, v
  {-0.5, -0.5,  0, 0  , 1},
  { 0  , -0.5,  0, 0.5, 1},
  {-0.5,  0.5,  0, 0  , 0},
  { 0  ,  0.5,  0, 0.5, 0},
}, 'strip', 'static')
local laneMeshRight = love.graphics.newMesh({
  {'VertexPosition', 'float', 3}, -- introduce Z axis
  {'VertexTexCoord', 'float', 2}, -- UVs
  -- ignore color
}, {
  -- x, y, z, u, v
  { 0  , -0.5,  0, 0.5, 1},
  { 0.5, -0.5,  0, 1  , 1},
  { 0  ,  0.5,  0, 0.5, 0},
  { 0.5,  0.5,  0, 1  , 0},
}, 'strip', 'static')

local vertShader = love.graphics.newShader([[
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

vec4 position(mat4 transformProjection, vec4 vertexPosition) {
  return projectionMatrix * viewMatrix * modelMatrix * vertexPosition;
}
]])

local glyphsList = require 'assets.sprites.controller'
local glyphs = {}
local loadedGlyphs

local function loadGlyphs(layout)
  glyphs = {}

  loadedGlyphs = layout
  if layout == '' then return end
  if not includes(glyphsList, layout) then
    error('no such glyphs ' .. layout, 2)
  end

  for _, key in ipairs({
    'key_1', 'key_2', 'key_3', 'key_4', 'key_5', 'key_6',
    'key_gear_l', 'key_gear_r',
    'key_gear_l_in', 'key_gear_l_out',
    'key_gear_r_in', 'key_gear_r_out',
  }) do
    local path = 'assets/sprites/controller/' .. layout .. '/' .. key .. '.png'
    if love.filesystem.getInfo(path, 'file') then
      glyphs[key] = love.graphics.newImage(path)
    end
  end
end
loadGlyphs('keyboard')

---@type TimingEvent[]
local timingEvents = {}

local TIMING_PAD = 4
local TIMING_SPACING = 8

local TOOLTIP_WIDTH = 140
local TOOLTIP_PAD = 4

---@class TimingEvent
---@field text string
---@field textObj love.Text
---@field col color
---@field x number
---@field beat number
---@field width number
---@field height number
---@field event XDRVThing
---@field hoverText love.Text
---@field hoverSummary love.Text
---@field type string
---@field invalid boolean

---@param event TimingEvent
local function shouldRenderTimingEvent(event)
  if event.invalid then return config.config.view.invalidEvents end
  return true
end

function self.updateTimingEvents()
  timingEvents = {}

  --print('update timing events')

  if not chart.loaded then return end

  for _, thing in ipairs(chart.chart) do
    local x = GAP_WIDTH/2 + NOTE_WIDTH * 3 + 52

    local lastEvent = timingEvents[#timingEvents]
    if lastEvent and beatCmp(thing.beat, lastEvent.beat) then
      x = lastEvent.x + lastEvent.width + TIMING_SPACING
    end

    local col, text, hoverText, hoverSummary
    local invalid = false

    if thing.bpm then
      col = rgb(0.6, 0.2, 0.2)
      text = string.format('%.3f', thing.bpm)
      hoverText = 'BPM Change'
      hoverSummary = string.format('%.3f BPM', thing.bpm)
    elseif thing.warp then
      col = rgb(0.6, 0.2, 0.6)
      text = string.format('%.3f', thing.warp)
      hoverText = 'Warp'
      hoverSummary = string.format('%.3f beats', thing.warp)
    elseif thing.stop then
      col = hex('bbd06c')
      text = string.format('%.3f', thing.stop)
      hoverText = 'Stop'
      hoverSummary = string.format('%.3f beats', thing.stop)
    elseif thing.stopSeconds then
      col = hex('bbd06c')
      text = string.format('%.3fs', thing.stopSeconds)
      hoverText = 'Stop'
      hoverSummary = string.format('%.3f seconds', thing.stopSeconds)
    elseif thing.scroll then
      col = hex('66aaff')
      text = string.format('x%.2f', thing.scroll)
      hoverText = 'Scroll'
      hoverSummary = string.format('%.3fx', thing.scroll)
    elseif thing.timeSignature then
      col = rgb(0.9, 0.1, 0.4)
      text = string.format('%i/%i', thing.timeSignature[1], thing.timeSignature[2])
      hoverText = 'Time Signature'
      hoverSummary = string.format('%i/%i', thing.timeSignature[1], thing.timeSignature[2])
    elseif thing.comboTicks then
      col = rgb(0.3, 0.4, 0.7)
      text = string.format('x%.2f', thing.comboTicks)
      hoverText = 'Combo Ticks'
      hoverSummary = string.format('x%.2f', thing.comboTicks)
    elseif thing.label then
      col = hex('3386ff')
      text = thing.label
      hoverText = 'Label'
      hoverSummary = '"' .. thing.label .. '"'
    elseif thing.fake then
      col = rgb(0.6, 0.1, 0.7)
      text = string.format('x%.2fb', thing.fake[1])
      hoverText = 'Fake'
      hoverSummary = string.format('x%.2fb', thing.fake[1])
      if thing.fake[2] then
        hoverSummary = hoverSummary .. ' (column ' .. thing.fake[2] .. ')'
      end
    elseif thing.measureLine then
      col = rgb(0.2, 0.6, 0.3)
      text = 'Measure Line'
      hoverText = 'Measure Line'
      if thing.measureLine == xdrv.XDRVLane.Left then
        hoverSummary = 'Left lane'
      elseif thing.measureLine == xdrv.XDRVLane.Right then
        hoverSummary = 'Right lane'
      else
        hoverSummary = 'Both lanes'
      end
    elseif not (thing.note or thing.gearShift or thing.drift or thing.checkpoint) then
      local type = getThingType(thing)
      invalid = true
      col = rgb(0.6, 0.1, 0.7)
      text = type
      hoverText = type
      hoverSummary = string.gsub(pretty(thing[type]), '\n', '')
    end

    if text then
      --local height = fonts.inter_16:getHeight() + TIMING_PAD * 2
      local height = 20
      local textObj = love.graphics.newText(fonts.inter_16, text)
      local width = textObj:getWidth() + TIMING_PAD * 2

      local event = {
        text = text,
        textObj = textObj,
        col = col,
        x = x,
        beat = thing.beat,
        width = width,
        height = height,
        event = thing,
        type = hoverText,
        hoverText = newWrapText(fonts.inter_16, hoverText, TOOLTIP_WIDTH - TOOLTIP_PAD * 2),
        hoverSummary = newWrapText(fonts.inter_12, hoverSummary, TOOLTIP_WIDTH - TOOLTIP_PAD * 2),
        invalid = invalid,
      }

      if shouldRenderTimingEvent(event) then
        table.insert(timingEvents, event)
      end
    end
  end
end

local cacheCanvas

local function initCanvases()
  canvas3d = love.graphics.newCanvas(CANVAS_PAD * 2 + NOTE_WIDTH * 6 + GAP_WIDTH, love.graphics.getHeight() * 4)
  laneMeshLeft:setTexture(canvas3d)
  laneMeshRight:setTexture(canvas3d)
  cacheCanvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight(), {
    msaa = 2
  })
end
initCanvases()

---@type TimingEvent?
local hoveredEvent
---@type ContextWidget?
local hoveredEventCtx

-- Must optionally be static; this is the chart body
---@param static boolean
function self.drawCanvas(static)
  local sw, sh, scx, scy = screenCoords()

  if loadedGlyphs ~= config.config.controllerGlyphs then
    loadGlyphs(config.config.controllerGlyphs)
  end

  if not static then
    for _, ease in ipairs(laneActive) do
      ease:update(love.timer.getDelta())
    end
  else
    for _, ease in ipairs(laneActive) do
      ease:reset(0)
    end
  end

  cachedScrollSpeed = preview.getScrollSpeed(conductor.beat)

  local noNotes = getScrollSpeed() <= EPSILON

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

  if config.config.previewMode then
    love.graphics.setBlendMode('add')
    love.graphics.setColor(getLaneColor(xdrv.XDRVLane.Left):unpack(preview.getPathAlpha(xdrv.XDRVLane.Left)))
    love.graphics.draw(lightsGradMesh, 0, 0, 0, sw * 0.5, sh)
    love.graphics.setColor(getLaneColor(xdrv.XDRVLane.Right):unpack(preview.getPathAlpha(xdrv.XDRVLane.Right)))
    love.graphics.draw(lightsGradMesh, sw, 0, 0, -(sw * 0.5), sh)
    love.graphics.setColor(1, 1, 1, preview.getPathBloom(xdrv.XDRVLane.Left))
    love.graphics.draw(lightsGradMesh, 0, 0, 0, sw * 0.6, sh)
    love.graphics.setColor(1, 1, 1, preview.getPathBloom(xdrv.XDRVLane.Right))
    love.graphics.draw(lightsGradMesh, sw, 0, 0, -(sw * 0.6), sh)
    love.graphics.setBlendMode('alpha')
  end

  local prevCanvas = love.graphics.getCanvas()
  if config.config.previewMode then
    love.graphics.setCanvas(canvas3d)

    sw, sh = canvas3d:getDimensions()
    scx, scy = sw/2, sh/2

    love.graphics.clear(0, 0, 0, 0)
  end

  love.graphics.push()
  love.graphics.translate(scx, 0)

  love.graphics.setColor(
    preview.getModValue('lane_color_red'),
    preview.getModValue('lane_color_green'),
    preview.getModValue('lane_color_blue'),
    preview.getModValue('lane_color_alpha')
  )
  love.graphics.rectangle('fill', getLeft(), 0, getMLeft() - getLeft(), sh)
  love.graphics.rectangle('fill', getMRight(), 0, getRight() - getMRight(), sh)

  local padBottom = getPadBottom()

  if not noNotes then
    local topB = math.ceil(yToBeat(0, sh)) + 1
    local botB = math.floor(yToBeat(sh, sh)) - 1
    if config.config.previewMode then
      botB = math.ceil(conductor.beat)
    end

    love.graphics.setLineWidth(4 * scale())

    local nextMeasureI = 1
    local nextMeasure = conductor.measures[1]

    while nextMeasure and nextMeasure < botB do
      nextMeasureI = nextMeasureI + 1
      nextMeasure = conductor.measures[nextMeasureI]
    end

    for b = botB, topB do
      local y = beatToY(b, sh)

      love.graphics.setColor(0.6, 0.6, 0.6, 1)
      if b == nextMeasure then
        if not config.config.previewMode then
          love.graphics.print(tostring(nextMeasureI), math.floor(getRight() + 16), math.floor(y - love.graphics.getFont():getHeight()/2))
        end
        nextMeasureI = nextMeasureI + 1
        nextMeasure = conductor.measures[nextMeasureI]
        drawMeasureLine(b, sh)
      elseif not config.config.previewMode then
        drawMeasureLine(b, sh, 0.5)
      end
    end

    for _, thing in ipairs(chart.chart) do
      if thing.beat > topB then break end
      if thing.measureLine then
        drawMeasureLine(thing.beat, sh, 1, thing.measureLine)
      end
    end
    for _, thing in ipairs(preview.getMeasureLines()) do
      if thing.beat > topB then break end
      drawMeasureLine(thing.beat, sh, 1, thing.measureLine)
    end
  end

  love.graphics.setLineWidth(1 * scale())

  love.graphics.setColor(SEP_COL:unpack())
  for o = -1, 1, 2 do
    for i = 1, 2 do
      local x = o * (GAP_WIDTH/2 + NOTE_WIDTH * i) * scale()
      love.graphics.line(x, 0, x, sh - padBottom)
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

  if not static then
    for c = 1, 6 do
      local x = getColumnX(c)
      love.graphics.setColor(1, 1, 1, laneActive[c].eased * 0.45)
      love.graphics.draw(laneGradMesh, (x - NOTE_WIDTH/2) * scale(), 32, 0, NOTE_WIDTH * scale(), (sh - 32) - padBottom)
    end
  end

  for c = 1, 6 do
    local x = getColumnX(c)
    love.graphics.setColor(getColumnColor(c):unpack(0.5 + laneActive[c].eased * 0.5))
    if glyphs['key_' .. c] then
      local spr = glyphs['key_' .. c]
      local size = (NOTE_WIDTH * 0.92) / spr:getWidth() * scale()
      love.graphics.draw(spr, x * scale(), sh - padBottom + NOTE_WIDTH * 0.08, 0, size * 0.8, size, spr:getWidth()/2, 0)
    end
  end

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

  love.graphics.pop()

  love.graphics.setCanvas(prevCanvas)

  sw, sh, scx, scy = screenCoords()

  if config.config.previewMode then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')

    love.graphics.push()
    love.graphics.origin()

    --love.graphics.setMeshCullMode('back')

    local ratio = canvas3d:getWidth() / canvas3d:getHeight()

    love.graphics.setShader(vertShader)

    -- WHY ?????????????????
    local yMult = prevCanvas and -1 or 1

    -- U = unity units
    local playfieldWidthU = (NOTE_WIDTH * 6 + GAP_WIDTH) / BASE_SCALE
    local canvasWidthU = playfieldWidthU - (CANVAS_PAD * 2) / BASE_SCALE

    local modelScale = canvasWidthU/2
    --local modelScale = 2

    local v = cpml.mat4.new().from_direction(cpml.vec3(0, 0, 1), cpml.vec3(0, 1, 0))
    v:scale(v, {x = modelScale, y = modelScale / (ratio * 3.4), z = 1})

    local originalPosition = cpml.vec3(0, 3.1, -4)
    -- why is the y and z swapped and mirrored?
    -- good question!
    local camPos = cpml.vec3(
       preview.getModValue('camera_position_x'),
      -preview.getModValue('camera_position_z'),
      -preview.getModValue('camera_position_y'))
    local originalRotation = cpml.vec3(math.rad(59), 0, 0)
    local camRot = cpml.vec3(
      math.rad(preview.getModValue('camera_rotation_x')),
      math.rad(preview.getModValue('camera_rotation_y')),
      math.rad(preview.getModValue('camera_rotation_z')))

    local translate = originalPosition + camPos
    -- unsure of why i have to mess with the rotations here, but...
    local rotation = eulerToQuaternion((cpml.vec3(math.pi/2, 0, 0) - (originalRotation + camRot)):unpack())

    v:translate(v, translate)
    v = cpml.mat4.from_quaternion(rotation) * v

    v:scale(v, {x = -1, y = -1, z = -1})

    local p = cpml.mat4().from_perspective(clamp(preview.getModValue('camera_fov'), 1, 179), love.graphics.getWidth() / love.graphics.getHeight(), 0.3, 1000.0)
    p:scale(p, { x = 1, y = yMult, z = 1 })

    vertShader:send('viewMatrix', v:to_vec4s_cols())
    vertShader:send('projectionMatrix', p:to_vec4s_cols())

    local m = cpml.mat4()

    m:scale(m, {x = modelScale, y = modelScale / (ratio * 3.4), z = 1})
    m:translate(m,
      cpml.vec3(
         preview.getModValue('track_move_x') / modelScale,
         preview.getModValue('track_move_z') / modelScale,
        -preview.getModValue('track_move_y') / modelScale)
    )

    -- no fucking clue why there's a *0.75 here
    local origin = cpml.vec3(((NOTE_WIDTH * 3)/2 + GAP_WIDTH*0.75) / BASE_SCALE / modelScale, 0, 0)

    local mLeft = cpml.mat4(m)
    local leftRot = eulerToQuaternion((-cpml.vec3(
      math.rad(preview.getModValue('trackleft_rotation_x')),
      math.rad(preview.getModValue('trackleft_rotation_z')),
      math.rad(preview.getModValue('trackleft_rotation_y'))
    )):unpack())

    mLeft:translate(mLeft, origin)
    mLeft = cpml.mat4.from_quaternion(leftRot) * mLeft
    mLeft:translate(mLeft, -origin)
    mLeft:scale(mLeft, {x = 1, y = -1, z = 1})

    mLeft:translate(mLeft,
      cpml.vec3(
         preview.getModValue('trackleft_move_x') / modelScale,
         preview.getModValue('trackleft_move_z') / modelScale,
        -preview.getModValue('trackleft_move_y') / modelScale))
    local mRight = cpml.mat4(m)

    local rightRot = eulerToQuaternion((-cpml.vec3(
      math.rad(preview.getModValue('trackright_rotation_x')),
      math.rad(preview.getModValue('trackright_rotation_z')),
      math.rad(preview.getModValue('trackright_rotation_y'))
    )):unpack())

    mRight:translate(mRight, -origin)
    mRight = cpml.mat4.from_quaternion(rightRot) * mRight
    mRight:translate(mRight, origin)
    mRight:scale(mRight, {x = 1, y = -1, z = 1})

    mRight:translate(mRight,
      cpml.vec3(
         preview.getModValue('trackright_move_x') / modelScale,
         preview.getModValue('trackright_move_z') / modelScale,
        -preview.getModValue('trackright_move_y') / modelScale))

    vertShader:send('modelMatrix', mLeft:to_vec4s_cols())
    love.graphics.draw(laneMeshLeft)
    vertShader:send('modelMatrix', mRight:to_vec4s_cols())
    love.graphics.draw(laneMeshRight)
    love.graphics.setShader()

    love.graphics.setMeshCullMode('none')
    love.graphics.setBlendMode('alpha', 'alphamultiply')

    love.graphics.pop()
  end
end

-- Cannot be static; for animated / frequently updating anims
function self.drawPost()
  if not chart.loaded then return end

  local sw, sh, scx, scy = screenCoords()

  love.graphics.push()
  love.graphics.translate(scx, 0)

  local noNotes = getScrollSpeed() <= EPSILON

  if not config.config.previewMode then
    local checkBeat = canPlaceCheckpoint(love.mouse.getPosition())
    if checkBeat and config.config.view.checkpoints and not config.config.previewMode then
      drawCheckpoint({ beat = checkBeat }, sh)
    end

    local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())

    if hoveredEventCtx and hoveredEventCtx.delete then
      hoveredEventCtx = nil
    end

    if not hoveredEventCtx then
      hoveredEvent = nil
      for i = #timingEvents, 1, -1 do
        local event = timingEvents[i]
        local x, y = event.x * scale(), beatToY(event.beat, sh)
        local width, height = event.width, event.height
        local hovered = mx > x and mx < (x + width) and my > (y - height/2) and my < (y + height / 2)
        if hovered then
          hoveredEvent = event
          break
        end
        if y > sh then break end
      end
    end

    love.graphics.setFont(fonts.inter_16)

    for _, event in ipairs(timingEvents) do
      local x, y = event.x * scale(), beatToY(event.beat, sh)
      local width, height = event.width, event.height
      local hovered = hoveredEvent == event

      if y < 0 then break end
      if y < sh then
        local col = event.col
        if hovered then
          col = col * 0.6
        end
        love.graphics.setColor(col:unpack())
        love.graphics.rectangle('fill', x, y - height/2, width, height, 2, 2)
        love.graphics.polygon('fill', x - 6, y, x, y - 6, x, y + 6)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.draw(event.textObj, math.floor(x + 3), math.floor(y - event.textObj:getHeight()/2 + 2))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(event.textObj, math.floor(x + 3), math.floor(y - event.textObj:getHeight()/2))
      end
    end

    if hoveredEvent and not hoveredEventCtx then
      local event = hoveredEvent
      local x, y = event.x * scale(), beatToY(event.beat, sh)
      local width, height = event.width, event.height

      --local tooltipX = math.min(x + width/2 - TOOLTIP_WIDTH/2, sw/2 - TOOLTIP_WIDTH - 40)
      local tooltipX = math.min(mx - TOOLTIP_WIDTH/2, sw/2 - TOOLTIP_WIDTH - 40)
      local arrSize = 10
      local cx = clamp(mx, tooltipX + arrSize + 2, tooltipX + TOOLTIP_WIDTH - arrSize - 2)

      local tooltipHeight = 2 + event.hoverText:getHeight() + 2 + event.hoverSummary:getHeight() + 2

      local tooltipY = y + 20
      local flipped = false
      if tooltipY + tooltipHeight > (sh - 20) then
        flipped = true
        tooltipY = y - 20 - tooltipHeight
      end

      love.graphics.setLineWidth(1)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle('fill', tooltipX, tooltipY, TOOLTIP_WIDTH, tooltipHeight, 2, 2)
      love.graphics.setColor(0.3, 0.3, 0.3, 1)
      love.graphics.rectangle('line', tooltipX, tooltipY, TOOLTIP_WIDTH, tooltipHeight, 2, 2)
      if not flipped then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon('fill', cx - arrSize - 2, tooltipY + 2, cx, tooltipY - arrSize, cx + arrSize + 2, tooltipY + 2)
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.line(cx - arrSize, tooltipY, cx, tooltipY - arrSize, cx + arrSize, tooltipY)
      else
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon('fill', cx - arrSize - 2, tooltipY + tooltipHeight - 2, cx, tooltipY + tooltipHeight + arrSize, cx + arrSize + 2, tooltipY + tooltipHeight - 2)
        love.graphics.setColor(0.3, 0.3, 0.3, 1)
        love.graphics.line(cx - arrSize, tooltipY + tooltipHeight, cx, tooltipY + tooltipHeight + arrSize, cx + arrSize, tooltipY + tooltipHeight)
      end

      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.setFont(fonts.inter_16)
      love.graphics.draw(event.hoverText, tooltipX + TOOLTIP_PAD, tooltipY + 2)
      love.graphics.setColor(0.8, 0.8, 0.8, 1)
      love.graphics.setFont(fonts.inter_12)
      love.graphics.draw(event.hoverSummary, tooltipX + TOOLTIP_PAD, tooltipY + 2 + event.hoverText:getHeight() + 2)
    end
  end
  love.graphics.setFont(fonts.inter_12)

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

local cacheMiss = true
function self.redraw()
  cacheMiss = true
end

function self.ignoreCache()
  return conductor.isPlaying() or config.config.debug.alwaysIgnoreCache
end

function self.shouldRedraw()
  if self.ignoreCache() then return true end
  if cacheMiss then
    cacheMiss = false
    return true
  end
  return false
end

self.drawProfile = 0

function self.draw()
  if self.ignoreCache() then
    self.redraw()
    self.drawCanvas(false)
  else
    if self.shouldRedraw() then
      love.graphics.setCanvas(cacheCanvas)
      love.graphics.clear(0, 0, 0, 0)
      love.graphics.setBlendMode('alpha')
      local start = os.clock()
      self.drawCanvas(true)
      self.drawProfile = os.clock() - start
      love.graphics.setCanvas()
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode('alpha', 'premultiplied')
    love.graphics.draw(cacheCanvas)
    love.graphics.setBlendMode('alpha')
  end
  self.drawPost()
end

-- globals bc lua module resolution sucks
function laneHit(i)
  laneActive[i]:reset(1)
end
function laneRelease(i)
  laneActive[i]:set(0)
end

function self.mousepressed(x, y, button)
  if not chart.loaded then return end
  if hoveredEventCtx then
    hoveredEventCtx.delete = true
    hoveredEventCtx = nil
    return
  end

  if config.config.previewMode then return end
  if not config.config.view.chart then return end

  local check = canPlaceCheckpoint(x, y)
  if button == 1 and check and config.config.view.checkpoints then
    local name
    local existingCheckpoint = chart.findThingOfType(check, 'checkpoint')
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

  if button == 2 and hoveredEvent and not hoveredEventCtx then
    hoveredEventCtx = ContextWidget(x, y, {
      {'Edit', function()
        openWidget(EventEditWidget(hoveredEvent.event), true)
      end},
      {'Delete', function()
        chart.removeThing(chart.findThing(hoveredEvent.event))
        chart.insertHistory('Remove event')
      end},
      {'Hide \'' .. hoveredEvent.type .. '\' events (UNIMPLEMENTED)', function() end},
    })
    openWidget(hoveredEventCtx)
    return
  end
end
function self.mousereleased(x, y, button)
  if not chart.loaded then return end
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
  if not chart.loaded then return end
  local ctrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
  if MACOS then ctrl = love.keyboard.isDown('lgui') or love.keyboard.isDown('rgui') end
  if ctrl then
    config.config.scrollSpeed = config.config.scrollSpeed * (1 + math.max(math.min(delta / 12, 0.5), -0.5))
    logs.uplog('scrollspeed', string.format('Scroll speed: %.2f', config.config.scrollSpeed))
    events.redraw()
  else
    edit.setBeat(conductor.beat + sign(delta) * QUANTS[edit.quantIndex])
    edit.updateGhosts()
    conductor.initStates()
  end
end

function self.resize(w, h)
  initCanvases()
  self.redraw()
end

return self