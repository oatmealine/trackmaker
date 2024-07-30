local Node = require 'src.ui.node'
local colors = require 'src.colors'

---@class Label : Node
local Label = Node:extend()

function Label:new(x, y, text, font)
  self.x = x
  self.y = y
  self.text = text
  self.font = font or fonts.inter_12

  self:updateText()

  self.width = self.textObj:getWidth()
  self.height = self.textObj:getHeight()
end

function Label:updateText()
  self.textObj = love.graphics.newText(self.font, self.text)
end

function Label:draw()
  love.graphics.setColor(colors.text:unpack())
  love.graphics.draw(self.textObj, self.width/2 - self.textObj:getWidth()/2, self.height/2 - self.textObj:getHeight()/2)
end

return Label