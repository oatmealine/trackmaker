local self = {}

---@type Object
local Object = require 'lib.classic'

---@class Widget : Object
Widget = Object:extend()

local BORDER_WIDTH = 1
local BAR_HEIGHT = 24

function Widget:new(x, y)
  self.x = x or 0
  self.y = y or 0
  self.width = 256
  self.height = 256
  self.resizable = false
  self.hasWindowDecorations = true
  self.isMovable = true
  self.dragAnywhere = false
end

function Widget:getBoundingBox()
  if self.hasWindowDecorations then
    return self.x, self.y, self.x + self.width + BORDER_WIDTH * 2, self.y + BAR_HEIGHT + self.height + BORDER_WIDTH * 2
  else
    return self.x, self.y, self.x + self.width, self.y + self.height
  end
end

---@enum WidgetPointState
local WidgetPointState = {
  None = 1,
  Inside = 2,
  Bar = 3,
}

function Widget:click(x, y)
end

function Widget:clickFrame(x, y)
  local x1, y1, x2, y2 = self:getBoundingBox()
  local aabb = x >= x1 and x <= x2 and y >= y1 and y <= y2
  if not aabb then
    return WidgetPointState.None
  end

  if not self.hasWindowDecorations then
    self:click(x, y)
    return WidgetPointState.Inside
  end

  x = x - x1
  y = y - y1

  if x > BORDER_WIDTH and x < self.width - BORDER_WIDTH and y > BORDER_WIDTH and y < self.height - BORDER_WIDTH then
    if y > BORDER_WIDTH + BAR_HEIGHT then
      self:click(x - BORDER_WIDTH, y - BORDER_WIDTH - BAR_HEIGHT)
      return WidgetPointState.Inside
    else
      return WidgetPointState.Bar
    end
  end

  return WidgetPointState.None
end

function Widget:drawInner()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
end

function Widget:draw()
  love.graphics.push()

  love.graphics.translate(self.x, self.y)

  if self.hasWindowDecorations then
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(BORDER_WIDTH)
    love.graphics.rectangle('line', -BORDER_WIDTH/2, -BORDER_WIDTH/2, self.width + BORDER_WIDTH * 2.5, self.height + BAR_HEIGHT + BORDER_WIDTH * 2.5, 1, 1)

    love.graphics.rectangle('fill', BORDER_WIDTH, BORDER_WIDTH, self.width, BAR_HEIGHT)
  end

  love.graphics.push()

  if self.hasWindowDecorations then
    love.graphics.translate(BORDER_WIDTH, BAR_HEIGHT + BORDER_WIDTH)
  end

  self:drawInner()

  love.graphics.pop()

  love.graphics.pop()
end

local CatjamWidget = require 'src.widgets.catjam'
local InfobarWidget = require 'src.widgets.infobar'

---@type Widget?
local draggingWidget = nil
---@type number, number
local dragX, dragY = nil, nil

---@type Widget[]
local widgets = { CatjamWidget(), InfobarWidget() }

function self.draw()
  for _, widget in ipairs(widgets) do
    widget:draw()
  end
end

function self.mousepressed(x, y, button)
  if button == 1 then
    for i = #widgets, 1, -1 do
      local widget = widgets[i]
      local res = widget:clickFrame(x, y)
      if res ~= WidgetPointState.None then
        if (res == WidgetPointState.Bar or widget.dragAnywhere) and widget.isMovable then
          draggingWidget = widget
          dragX, dragY = x - widget.x, y - widget.y
        end
      end
    end
  end
end
function self.mousemoved(x, y)
  if draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
  end
end
function self.mousereleased(x, y, button)
  if button == 1 and draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
    draggingWidget = nil
  end
end

return self