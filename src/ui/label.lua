local Node = require 'src.ui.node'
local colors = require 'src.colors'

---@class Label : Node
local Label = Node:extend()

function Label:new(x, y, text, font)
  self.x = x
  self.y = y
  self.text = text
  self.font = font or fonts.inter_12
  self.textObj = love.graphics.newText(self.font, '')
  ---@type number | nil
  self.wrapWidth = nil
  ---@type love.AlignMode
  self.align = 'left'

  self:updateText()

  self.width = self.textObj:getWidth()
  self.height = self.textObj:getHeight()
end

---@param align love.AlignMode
function Label:setAlign(align)
  self.align = align
  self:updateText()
end
---@param n number | nil
function Label:setWrapWidth(n)
  self.wrapWidth = n
  self:updateText()
end

function Label:updateText()
  if not self.wrapWidth then
    self.textObj:set(self.text)
  else
    self.textObj:setf(self.text, self.wrapWidth, self.align)
  end
  self.width = self.textObj:getWidth()
  self.height = self.textObj:getHeight()
end

function Label:draw()
  love.graphics.setColor(colors.text:unpack())
  local x = 0
  if self.wrapWidth then
    x = x - self.wrapWidth/2 + self.width/2
  end
  love.graphics.draw(self.textObj, math.floor(x), 0)
end

return Label