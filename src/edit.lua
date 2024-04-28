local conductor = require 'src.conductor'
local chart     = require 'src.chart'
local xdrv      = require 'lib.xdrv'
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

---@param column XDRVNoteColumn
function self.placeNote(column)
  local beat = getBeat()

  if mode == self.Mode.Insert or mode == self.Mode.Append then
    local event = { beat = beat, note = { column = column } }
    local eventIdx = chart.findEvent(event)
    if eventIdx then
      chart.removeEvent(eventIdx)
    else
      chart.placeEvent(event)
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
    chart.placeEvent({ beat = beat, note = { column = column } })
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
function self.placeGearShift(lane)
  chart.placeEvent({ beat = getBeat(), gearShift = { lane = lane, length = 1 } })
end

---@param key love.KeyConstant
---@param code love.Scancode
function self.keypressed(key, code, isRepeat)
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
  elseif key == 'up' then
    setBeat(conductor.beat + QUANTS[self.quantIndex])
  elseif key == 'pagedown' then
    setBeat(conductor.beat - 4)
  elseif key == 'pageup' then
    setBeat(conductor.beat + 4)
  elseif key == 'left' then
    self.quantIndex = math.max(self.quantIndex - 1, 1)
  elseif key == 'right' then
    self.quantIndex = math.min(self.quantIndex + 1, #QUANTS)
  end

  if self.write then
    if key == 'escape' then
      self.write = false
    elseif key == 'tab' then
      cycleMode()
    elseif code == 'lshift' then
      self.placeGearShift(xdrv.XDRVLane.Left)
    elseif code == 'a' then
      self.placeNote(1)
    elseif code == 's' then
      self.placeNote(2)
    elseif code == 'd' then
      self.placeNote(3)
    elseif code == 'l' then
      self.placeNote(4)
    elseif code == ';' then
      self.placeNote(5)
    elseif code == '\'' then
      self.placeNote(6)
    elseif code == 'rshift' then
      self.placeGearShift(xdrv.XDRVLane.Right)
    end
  else
    if key == 'tab' then
      self.write = true
    end
  end
end

return self