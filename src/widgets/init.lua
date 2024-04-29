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
  self.delete = false
  self.ignoreFocus = false
end

function Widget:update()
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

function Widget:loseFocus()
end
function Widget:focus()
end

function Widget:click(x, y)
end

function Widget:pointInside(x, y)
  local x1, y1, x2, y2 = self:getBoundingBox()
  return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function Widget:clickFrame(x, y)
  if not self:pointInside(x, y) then
    return WidgetPointState.None
  end

  x = x - self.x
  y = y - self.y

  if not self.hasWindowDecorations then
    self:click(x, y)
    return WidgetPointState.Inside
  end

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

function Widget:move(x, y)
end

function Widget:moveFrame(x, y)
  -- todo: does not account for window decorations
  if self:pointInside(x, y) then
    self:move(x - self.x, y - self.y)
  end
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
    love.graphics.rectangle('line', 0, 0, self.width + BORDER_WIDTH * 2, self.height + BAR_HEIGHT + BORDER_WIDTH * 2, 1, 1)

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

---@type Widget[]
local widgets = { }

---@param w Widget
function openWidget(w)
  if widgets[#widgets] then
    widgets[#widgets]:loseFocus()
  end
  table.insert(widgets, w)
  w:focus()
  self.update()
end

local CatjamWidget = require 'src.widgets.catjam'
local InfobarWidget = require 'src.widgets.infobar'
local ContextWidget = require 'src.widgets.context'
local ActionBarWidget = require 'src.widgets.actionbar'

---@type Widget?
local draggingWidget = nil
---@type number, number
local dragX, dragY = nil, nil

widgets = { CatjamWidget(), InfobarWidget(), ActionBarWidget() }

function self.update()
  for i = #widgets, 1, -1 do
    local widget = widgets[i]
    widget:update()
    if widget.delete then
      table.remove(widgets, i)
      if i > #widgets and #widgets ~= 0 then
        widgets[#widgets]:focus()
      end
    end
  end
end

function self.draw()
  for _, widget in ipairs(widgets) do
    widget:draw()
  end
end

function self.mousepressed(x, y, button)
  for i = #widgets, 1, -1 do
    local widget = widgets[i]
    if button == 1 then
      local res = widget:clickFrame(x, y)
      if res ~= WidgetPointState.None then
        if (res == WidgetPointState.Bar or widget.dragAnywhere) and widget.isMovable then
          draggingWidget = widget
          dragX, dragY = x - widget.x, y - widget.y
        end
        -- move to front
        if i ~= #widgets and not widget.ignoreFocus then
          table.remove(widgets, i)
          widgets[#widgets]:loseFocus()
          table.insert(widgets, widget)
          widget:focus()
        end
        self.update()
        return
      end
    elseif button == 2 then
      if widget:pointInside(x, y) and widget.dragAnywhere then
        table.insert(widgets, ContextWidget(x, y, {
          { 'Close', function() widget.delete = true end }
        }))
      end
    end
  end
end
function self.mousemoved(x, y)
  if draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
  end
  for _, widget in ipairs(widgets) do
    widget:moveFrame(x, y)
  end
end
function self.mousereleased(x, y, button)
  if button == 1 and draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
    draggingWidget = nil
  end
end

return self