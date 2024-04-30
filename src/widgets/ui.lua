---@class UIWidget : Widget
local UIWidget = Widget:extend()

function UIWidget:new(x, y, container)
  UIWidget.super.new(self, x, y)
  ---@type Container
  self.container = container
end

function UIWidget:loseFocus()
  self.container:loseFocus()
end

function UIWidget:eatsInputs()
  return self.container:eatsInputs()
end

function UIWidget:key(key, scancode, isRepeat)
  self.container:key(key, scancode, isRepeat)
end

function UIWidget:click(x, y, button)
  self.container:click(x, y, button)
end
function UIWidget:move(x, y)
  self.container:move(x, y)
end

function UIWidget:update()
  self.container:update()
end

function UIWidget:draw()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  self.container:draw()
end

function UIWidget:textInput(t)
  self.container:textInput(t)
end

return UIWidget