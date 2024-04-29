local conductor = require 'src.conductor'
local chart     = require 'src.chart'
local xdrv      = require 'lib.xdrv'
local logs      = require 'src.logs'
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

---@type Mode
local mode = self.Mode.Insert
self.write = false
self.quantIndex = 1

self.viewBinds = false

local function cycleMode()
  mode = mode + 1
  if mode > self.Mode.Rewrite then
    mode = 1
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
  table.insert(ghosts, { beat = getBeat(), gearShift = { lane = lane, length = 0 } })
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

function self.cut()
  logs.log('Cut - Not implemented')
end
function self.copy()
  logs.log('Copy - Not implemented')
end
function self.paste()
  logs.log('Paste - Not implemented')
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
    if key == 'escape' then
      self.write = false
    elseif key == 'tab' then
      cycleMode()
    elseif code == 'lshift' then
      self.beginGearShift(xdrv.XDRVLane.Left)
    elseif code == 'a' then
      self.beginNote(1)
    elseif code == 's' then
      self.beginNote(2)
    elseif code == 'd' then
      self.beginNote(3)
    elseif code == 'l' then
      self.beginNote(4)
    elseif code == ';' then
      self.beginNote(5)
    elseif code == '\'' then
      self.beginNote(6)
    elseif code == 'rshift' then
      self.beginGearShift(xdrv.XDRVLane.Right)
    end
  else
    if key == 'tab' then
      self.write = true
    end
  end
end

---@param key love.KeyConstant
---@param code love.Scancode
function self.keyreleased(key, code)
  if self.write then
    if code == 'lshift' then
      self.endGearShift(xdrv.XDRVLane.Left)
    elseif code == 'a' then
      self.endNote(1)
    elseif code == 's' then
      self.endNote(2)
    elseif code == 'd' then
      self.endNote(3)
    elseif code == 'l' then
      self.endNote(4)
    elseif code == ';' then
      self.endNote(5)
    elseif code == '\'' then
      self.endNote(6)
    elseif code == 'rshift' then
      self.endGearShift(xdrv.XDRVLane.Right)
    end
  end
end

return self