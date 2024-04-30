---@type Object
local Object = require 'lib.classic'

---@class Node : Object
local Node = Object:extend()

function Node:new(x, y)
  self.x = x
  self.y = y
  self.width = 32
  self.height = 32

  self.hovered = false
  self.active = false
end

function Node:inBounds(x, y)
  return x >= self.x and x <= (self.x + self.width) and y > self.y and y <= (self.y + self.height)
end

function Node:click(x, y, button)
end
function Node:move(x, y)
  self.hovered = x >= 0 and y >= 0 and x <= self.width and y <= self.height
end
---@param key love.KeyConstant
---@param scancode love.Scancode
---@param isRepeat boolean
function Node:key(key, scancode, isRepeat)
end
function Node:eatsInputs()
  return false
end
function Node:textInput(t)
end
function Node:update()
end
function Node:draw()
end

return Node