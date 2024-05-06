local Node = require 'src.ui.node'
local colors = require 'src.colors'

---@class Checkmark : Node
local Checkmark = Node:extend()

local SIZE = 16

function Checkmark:new(x, y, trigger, default, disabled)
  self.x = x
  self.y = y
  self.trigger = trigger

  self.enabled = default
  self.disabled = disabled

  self.width = SIZE
  self.height = SIZE
end

function Checkmark:click(x, y, button)
  if button == 1 and not self.disabled then
    self.enabled = not self.enabled
    self:trigger(self.enabled)
  end
end

function Checkmark:draw()
  if self.hovered and not self.disabled then
    if love.mouse.isDown(1) then
      love.graphics.setColor(colors.down:unpack())
    else
      love.graphics.setColor(colors.hover:unpack())
    end
  else
    love.graphics.setColor(colors.element:unpack())
  end
  love.graphics.rectangle('fill', 0, 0, self.width, self.height, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.border:unpack())
  love.graphics.rectangle('line', 0, 0, self.width, self.height, 1, 1)

  if self.disabled then
    love.graphics.setColor(colors.textSecondary:unpack())
  elseif self.hovered and love.mouse.isDown(1) then
    love.graphics.setColor((colors.activeText or colors.text):unpack())
  elseif self.hovered then
    love.graphics.setColor((colors.hoverText or colors.text):unpack())
  else
    love.graphics.setColor(colors.text:unpack())
  end
  if self.enabled then
    love.graphics.printf('✓', 0, self.height/2 - fonts.inter_12:getHeight()/2, self.width, 'center')
  end
end

return Checkmark