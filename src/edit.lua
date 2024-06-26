local conductor = require 'src.conductor'
local xdrv      = require 'lib.xdrv'
local logs      = require 'src.logs'
local clipboard = require 'src.clipboard'
local self = {}

---@enum Mode
self.Mode = {
  -- Technically not a mode. Implies write = false
  None = 0,
  -- ArrowVortex-style insert mode. Press a key to set or unset a note.
  Insert = 1,
  -- Move forward after adding a note.
  Append = 2,
  -- Move to the next row and overwrite the last after adding a note.
  Rewrite = 3,
}

---@param mode Mode
function self.modeName(mode)
  if mode == self.Mode.None then return 'None' end
  if mode == self.Mode.Insert then return 'Insert' end
  if mode == self.Mode.Append then return 'Append' end
  if mode == self.Mode.Rewrite then return 'Rewrite' end
end

---@type XDRVEvent[]
self.selection = {}

function self.clearSelection()
  self.selection = {}
end

---@type Mode
local mode = self.Mode.Insert
self.write = false
self.quantIndex = 1

self.viewBinds = false

function self.cycleMode()
  if self.write then
    mode = mode + 1
    if mode > self.Mode.Rewrite then
      mode = 1
    end
  else
    self.write = true
  end
end

function self.getMode()
  if not self.write then return self.Mode.None end
  return mode
end

local function getBeat()
  return quantize(conductor.beat, self.quantIndex)
end
local function setBeat(b)
  conductor.seekBeats(quantize(b, self.quantIndex))
end

---@type (XDRVNote | XDRVGearShift)[]
local ghosts = { }

function self.getGhosts()
  local saneGhosts = {}

  for _, ghost in ipairs(ghosts) do
    if ghost.note then
      local beat = ghost.beat
      local length = ghost.note.length or 0
      if length < 0 then
        beat = beat + length
        length = -length
      end
      if length == 0 then
        length = nil
      end
      table.insert(saneGhosts, {
        beat = beat,
        note = { column = ghost.note.column, length = length },
      })
    elseif ghost.gearShift then
      local beat = ghost.beat
      local length = ghost.gearShift.length
      if length < 0 then
        beat = beat + length
        length = -length
      end
      table.insert(saneGhosts, {
        beat = beat,
        gearShift = { lane = ghost.gearShift.lane, length = length },
      })
    end
  end

  return saneGhosts
end

---@param column XDRVNoteColumn
function self.beginNote(column)
  local beat = getBeat()

  if mode == self.Mode.Insert or mode == self.Mode.Append then
    local event = { beat = beat, note = { column = column } }
    local eventIdx = chart.findEvent(event)
    if eventIdx then
      chart.removeEvent(eventIdx)
      logs.log('Removed note')
    else
      table.insert(ghosts, event)
    end
    if mode == self.Mode.Append then
      setBeat(beat + QUANTS[self.quantIndex])
    end
  else
    local event = { beat = beat, note = { } }
    local eventIdx = chart.findEvent(event)
    local lastIdx = eventIdx or 1
    while eventIdx do
      chart.removeEvent(eventIdx)
      lastIdx = eventIdx
      eventIdx = chart.findEvent(event)
    end
    local placed = { beat = beat, note = { column = column } }
    table.insert(ghosts, placed)
    for i = lastIdx, #chart.chart do
      local ev = chart.chart[i]
      if ev.beat > beat then
        self.quantIndex = getQuantIndex(ev.beat)
        setBeat(ev.beat)
        break
      end
    end
  end
end
---@param lane XDRVLane
function self.beginGearShift(lane)
  local beat = getBeat()
  local event = { beat = beat, gearShift = { lane = lane } }

  local eventIdx = chart.findEvent(event)

  if eventIdx then
    chart.removeEvent(eventIdx)
    logs.log('Removed gear shift')
  else
    table.insert(ghosts, { beat = getBeat(), gearShift = { lane = lane, length = 0 } })
  end
end

---@param dir XDRVDriftDirection
function self.placeDrift(dir)
  local beat = getBeat()
  local event = { beat = beat, drift = { } }
  local eventIdx = chart.findEvent(event)
  local cmpEvent = chart.chart[eventIdx]

  if eventIdx then
    chart.removeEvent(eventIdx)
  end

  if not eventIdx or cmpEvent.drift.direction ~= dir then
    chart.placeEvent({ beat = beat, drift = { direction = dir } })
    logs.log(eventIdx and 'Replaced drift' or 'Placed drift')
  else
    logs.log('Removed drift')
  end
end

function self.endNote(column)
  for i = #ghosts, 1, -1 do
    local ghost = ghosts[i]
    if ghost.note and ghost.note.column == column then
      ghost.note.length = ghost.note.length or 0
      if ghost.note.length < 0 then
        ghost.beat = ghost.beat + ghost.note.length
        ghost.note.length = math.abs(ghost.note.length)
      end
      if ghost.note.length == 0 then
        ghost.note.length = nil
      end
      chart.placeEvent(ghost)
      logs.log('Placed note')
      table.remove(ghosts, i)
    end
  end
end

function self.endGearShift(lane)
  for i = #ghosts, 1, -1 do
    local ghost = ghosts[i]
    if ghost.gearShift and ghost.gearShift.lane == lane then
      if ghost.gearShift.length < 0 then
        ghost.beat = ghost.beat + ghost.gearShift.length
        ghost.gearShift.length = math.abs(ghost.gearShift.length)
      end
      if ghost.gearShift.length ~= 0 then
        chart.placeEvent(ghost)
        logs.log('Placed gear shift')
      end
      table.remove(ghosts, i)
    end
  end
end

function self.updateGhosts()
  for _, ghost in ipairs(ghosts) do
    local ev = ghost.note or ghost.gearShift
    if ev then
      ev.length = conductor.beat - ghost.beat
    end
  end
end

---@enum MirrorType
self.MirrorType = {
  Horizontal = 0,
  Vertical = 1,
  Both = 2,
}

---@param c XDRVNoteColumn
local function mirrorColumnHoriz(c)
  return 7 - c
end
---@param c XDRVNoteColumn
local function mirrorColumnVert(c)
  if c < 3 then
    -- 1 -> 2, 2 -> 1
    return 3 - c
  end
  if c > 4 then
    -- 5 -> 6, 6 -> 5
    return 11 - c
  end
  return c
end
---@param l XDRVLane
local function mirrorLane(l)
  if l == xdrv.XDRVLane.Left then return xdrv.XDRVLane.Right end
  return xdrv.XDRVLane.Left
end
---@param d XDRVDriftDirection
local function mirrorDriftDir(d)
  if d == xdrv.XDRVDriftDirection.Left  then return xdrv.XDRVDriftDirection.Right end
  if d == xdrv.XDRVDriftDirection.Right then return xdrv.XDRVDriftDirection.Left  end
  return xdrv.XDRVDriftDirection.Neutral
end

---@param m MirrorType
local function mirrorStr(m)
  if m == self.MirrorType.Horizontal then
    return 'horizontally'
  end
  if m == self.MirrorType.Vertical then
    return 'vertically'
  end
  return 'horizontally and vertically'
end

---@param type MirrorType
function self.mirrorSelection(type)
  local isHorizontal = type == self.MirrorType.Horizontal or type == self.MirrorType.Both
  local isVertical = type == self.MirrorType.Vertical or type == self.MirrorType.Both
  for _, event in ipairs(self.selection) do
    if event.note then
      if isHorizontal then
        event.note.column = mirrorColumnHoriz(event.note.column)
      end
      if isVertical then
        event.note.column = mirrorColumnVert(event.note.column)
      end
    end
    if event.gearShift and isHorizontal then
      event.gearShift.lane = mirrorLane(event.gearShift.lane)
    end
    if event.drift then
      event.drift.direction = mirrorDriftDir(event.drift.direction)
    end
  end
  logs.log('Mirrored ' .. #self.selection .. ' events ' .. mirrorStr(type))
  chart.markDirty()
end

function self.deleteSelection()
  if not chart.loaded then return end
  for i = #chart.chart, 1, -1 do
    local event = chart.chart[i]
    if includes(self.selection, event) then
      table.remove(chart.chart, i)
    end
  end
end
function self.deleteKey()
  self.deleteSelection()
  logs.log('Deleted ' .. #self.selection .. ' events')
  self.clearSelection()
  chart.markDirty()
end

function self.selectAll()
  if not chart.loaded then return end
  self.clearSelection() -- bugfix by regen=Q

  for _, event in ipairs(chart.chart) do
    table.insert(self.selection, event)
  end
  logs.log('Selected ' .. #self.selection .. ' events')
end

function self.undo()
  logs.log('Undo - not implemented')
end
function self.redo()
  logs.log('Redo - not implemented')
end

function self.cut()
  self.deleteSelection()
  self.copy()
end
function self.copy()
  if not chart.loaded then return end
  if #self.selection == 0 then
    logs.log('Nothing to copy')
    love.system.setClipboardText('')
    return
  end

  local text = clipboard.encode(self.selection)

  love.system.setClipboardText(text)
  local chk = love.system.getClipboardText()
  if text ~= chk then
    logs.log('System clipboard unavailable?')
  end

  logs.log('Copied ' .. #self.selection .. ' events')
  self.clearSelection()

  chart.markDirty()
end
function self.paste()
  if not chart.loaded then return end

  local clip = love.system.getClipboardText()

  local events = clipboard.decode(clip)

  if not events then
    logs.log('Nothing in clipboard')
    return
  end

  self.clearSelection()

  local b = getBeat()
  for _, event in ipairs(events) do
    event.beat = event.beat + b
    chart.placeEvent(event)
    table.insert(self.selection, event)
  end

  logs.log('Pasted ' .. #events .. ' events')

  chart.markDirty()
end

---@param key love.KeyConstant
---@param code love.Scancode
function self.keypressed(key, code, isRepeat)
  if key == 'escape' and self.viewBinds then
    self.viewBinds = false
    return
  end

  local ctrl = love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl')
  local shift = love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')

  ---@type Keybind[]
  local triggeredKeybinds = {}
  for _, bind in pairs(keybinds.binds) do
    if
      not (bind.ctrl and not ctrl) and
      not (bind.shift and not shift) and
      not (bind.viewOnly and self.write) and
      not (bind.writeOnly and not self.write) and
      not (not bind.canRepeat and isRepeat) and
      not (not bind.alwaysUsable and self.viewBinds)
    then
      local isInvalid = false
      for _, k in ipairs(bind.keys or {}) do
        if not love.keyboard.isScancodeDown(k) then
          isInvalid = true
          break
        end
      end
      for _, k in ipairs(bind.keyCodes or {}) do
        if not love.keyboard.isDown(k) then
          isInvalid = true
          break
        end
      end
      if not bind.keys and not bind.keyCodes then isInvalid = true end

      if not isInvalid then
        table.insert(triggeredKeybinds, bind)
      end
    end
  end

  if #triggeredKeybinds <= 1 then
    local bind = triggeredKeybinds[1]
    if bind and bind.trigger then bind.trigger() end
    if bind then return end
  else
    -- resolve via priority
    local maxPrio = 0
    local maxBind
    for _, bind in ipairs(triggeredKeybinds) do
      local prio = 0
      if bind.shift then prio = prio + 2 end
      if bind.ctrl then prio = prio + 2 end
      if bind.keys then prio = prio + #bind.keys end
      if bind.keyCodes then prio = prio + #bind.keyCodes end
      if prio > maxPrio then
        maxPrio = prio
        maxBind = bind
      end
    end

    if maxBind.trigger then maxBind.trigger() end
    return
  end

  if self.viewBinds then return end

  if key == 'space' then
    if conductor.isPlaying() then
      conductor.pause()
    else
      conductor.play()
    end
  elseif key == 'down' then
    setBeat(conductor.beat - QUANTS[self.quantIndex])
    self.updateGhosts()
  elseif key == 'up' then
    setBeat(conductor.beat + QUANTS[self.quantIndex])
    self.updateGhosts()
  elseif key == 'pagedown' then
    setBeat(conductor.beat - 4)
    self.updateGhosts()
  elseif key == 'pageup' then
    setBeat(conductor.beat + 4)
    self.updateGhosts()
  elseif key == 'left' then
    self.quantIndex = math.max(self.quantIndex - 1, 1)
  elseif key == 'right' then
    self.quantIndex = math.min(self.quantIndex + 1, #QUANTS)
  end

  if isRepeat then return end

  if self.write then
    if code == 'lshift' then
      self.beginGearShift(xdrv.XDRVLane.Left)
    elseif code == 'a' or code == '1' then
      self.beginNote(1)
    elseif code == 's' or code == '2' then
      self.beginNote(2)
    elseif code == 'd' or code == '3' then
      self.beginNote(3)
    elseif code == 'l' or code == '4' then
      self.beginNote(4)
    elseif code == ';' or code == '5' then
      self.beginNote(5)
    elseif code == '\'' or code == '6' then
      self.beginNote(6)
    elseif code == 'rshift' then
      self.beginGearShift(xdrv.XDRVLane.Right)
    elseif code == ',' then
      self.placeDrift(xdrv.XDRVDriftDirection.Left)
    elseif code == '.' then
      self.placeDrift(xdrv.XDRVDriftDirection.Right)
    elseif code == '/' then
      self.placeDrift(xdrv.XDRVDriftDirection.Neutral)
    end
  else
    if
      code == 'a' or code == '1' or
      code == 's' or code == '2' or
      code == 'd' or code == '3' or
      code == 'l' or code == '4' or
      code == ';' or code == '5' or
      code == '\'' or code == '6'
    then
      logs.log('You must be in write mode to do this! (Press ' .. keybinds.formatBind(keybinds.binds.cycleMode) .. ')')
    end
  end
end

---@param key love.KeyConstant
---@param code love.Scancode
function self.keyreleased(key, code)
  if self.write and #ghosts > 0 then
    if code == 'lshift' then
      self.endGearShift(xdrv.XDRVLane.Left)
    elseif code == 'a' or code == '1' then
      self.endNote(1)
    elseif code == 's' or code == '2' then
      self.endNote(2)
    elseif code == 'd' or code == '3' then
      self.endNote(3)
    elseif code == 'l' or code == '4' then
      self.endNote(4)
    elseif code == ';' or code == '5' then
      self.endNote(5)
    elseif code == '\'' or code == '6' then
      self.endNote(6)
    elseif code == 'rshift' then
      self.endGearShift(xdrv.XDRVLane.Right)
    end
  end
end

return self