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

---@param event XDRVEvent
local function placeEvent(event)
  for i, ev in ipairs(chart.chart) do
    if ev.beat > event.beat then
      table.insert(chart.chart, i - 1, event)
      return
    end
  end
  table.insert(chart.chart, event)
end

---@param column XDRVNoteColumn
function self.placeNote(column)
  chart.markDirty()
  placeEvent({ beat = conductor.beat, note = { column = column } })
end
---@param lane XDRVLane
function self.placeGearShift(lane)
  placeEvent({ beat = conductor.beat, gearShift = { lane = lane, length = 1 } })
end

---@param key love.KeyConstant
---@param code love.Scancode
function self.keypressed(key, code)
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
    if key == 's' and love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
      chart.saveChart()
    elseif key == 'tab' then
      self.write = true
    end
  end
end

return self