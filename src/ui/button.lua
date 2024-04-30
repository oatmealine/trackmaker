local Node = require 'src.ui.node'

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
  if button == 1 then
    self:trigger()
  end
end

function Button:draw()
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
  love.graphics.draw(self.textObj, self.width/2 - self.textObj:getWidth()/2, self.height/2 - self.textObj:getHeight()/2)
end

return Button