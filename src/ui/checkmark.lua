local Node = require 'src.ui.node'

---@class Checkmark : Node
local Checkmark = Node:extend()

local SIZE = 16

function Checkmark:new(x, y, trigger, default)
  self.x = x
  self.y = y
  self.trigger = trigger

  self.enabled = default

  self.width = SIZE
  self.height = SIZE
end

function Checkmark:click(x, y, button)
  if button == 1 then
    self.enabled = not self.enabled
    self:trigger(self.enabled)
  end
end

function Checkmark:draw()
  if self.hovered then
    if love.mouse.isDown(1) then
      love.graphics.setColor(0.1, 0.1, 0.1, 1)
    else
      love.graphics.setColor(0.3, 0.3, 0.3, 1)
    end
  else
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
  end
  love.graphics.rectangle('fill', 0, 0, self.width, self.height, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.3, 0.3, 0.3, 1)
  love.graphics.rectangle('line', 0, 0, self.width, self.height, 1, 1)

  love.graphics.setColor(1, 1, 1, 1)
  if self.enabled then
    love.graphics.printf('✓', 0, self.height/2 - fonts.inter_12:getHeight()/2, self.width, 'center')
  end
end

return Checkmark