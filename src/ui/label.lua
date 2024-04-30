local Node = require 'src.ui.node'

---@class Label : Node
local Label = Node:extend()

function Label:new(x, y, text)
  self.x = x
  self.y = y
  self.text = text

  self:updateText()

  self.width = self.textObj:getWidth()
  self.height = self.textObj:getHeight()
end

function Label:updateText()
  self.textObj = love.graphics.newText(fonts.inter_12, self.text)
end

function Label:draw()
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.textObj, self.width/2 - self.textObj:getWidth()/2, self.height/2 - self.textObj:getHeight()/2)
end

return Label