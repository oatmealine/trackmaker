local conductor = require 'src.conductor'

---@class CatjamWidget : Widget
local CatjamWidget = Widget:extend()

function CatjamWidget:new(x, y)
  CatjamWidget.super.new(self, x, y)
  self.dragAnywhere = true
  self.hasWindowDecorations = false
  self.resizable = false
  self.width = 128
  self.height = 128
end

local BOBS = 6.5
local FRAMES_N = 79
local FRAMES = {}

for i = 0, FRAMES_N - 1 do
  table.insert(FRAMES, love.graphics.newImage('assets/sprites/catjam/catjam' .. lpad(tostring(i), 2, '0') .. '.png'))
end

local function pingpong(x)
  return math.abs(x % 2 - 1)
end

function CatjamWidget:drawInner()
  local b = conductor.beat

  -- assuming 2 bobs per beat
  local a = pingpong(b / BOBS)
  local f = math.max(math.min(math.floor(1 + a * #FRAMES), #FRAMES), 1)
  local frame = FRAMES[f]

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(frame)
end

return CatjamWidget