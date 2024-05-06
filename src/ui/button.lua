local Node = require 'src.ui.node'
local colors = require 'src.colors'

---@class Button : Node
local Button = Node:extend()

local PAD_H = 6
local PAD_V = 4

function Button:new(x, y, text, trigger)
  self.x = x
  self.y = y
  self.text = text
  self.trigger = trigger

  self.textObj = love.graphics.newText(fonts.inter_12, self.text)

  self.width = PAD_H * 2 + self.textObj:getWidth()
  self.height = PAD_V * 2 + self.textObj:getHeight()
end

function Button:click(x, y, button)
  if button == 1 and not self.disabled then
    self:trigger()
  end
end

function Button:draw()
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
  love.graphics.draw(self.textObj, self.width/2 - self.textObj:getWidth()/2, self.height/2 - self.textObj:getHeight()/2)
end

return Button