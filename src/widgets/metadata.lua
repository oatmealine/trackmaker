---@class MetadataWidget : Widget
local MetadataWidget = Widget:extend()

function MetadataWidget:new(x, y)
  MetadataWidget.super.new(self, x, y)
  self.width = 180
  self.height = 300
end

function MetadataWidget:drawInner()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
  love.graphics.setColor(0.6, 0.6, 0.6, 1)
  love.graphics.printf('SORRY NOTHING', 0, self.height/2, self.width, 'center')
end

return MetadataWidget