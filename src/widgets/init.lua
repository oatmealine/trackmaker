local self = {}

---@type Object
local Object = require 'lib.classic'

local colors = require 'src.colors'

---@class Widget : Object
Widget = Object:extend()

local BORDER_WIDTH = 1
local BAR_HEIGHT = 24

local crossIcon = love.graphics.newImage('assets/sprites/icons/cross.png')

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
  self.focused = false
  self.dragged = false

  self.name = 'Widget'
  self.title = nil
end

function Widget:__tostring()
  local meta = getmetatable(self)
  local t = setmetatable(self, nil)
  local hash = string.match(tostring(t), '(0x%S+)')
  setmetatable(self, meta)
  return self.name .. ' (' .. hash .. ')'
end

function Widget:update()
end

---@param name string
function Widget:event(name)
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

---@param to Widget
function Widget:loseFocus(to)
end
function Widget:focus()
end

function Widget:pointInside(x, y)
  local x1, y1, x2, y2 = self:getBoundingBox()
  return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function Widget:translateLocal(x, y)
  return x - self.x, y - self.y
end
function Widget:translateInside(x, y)
  if not self.hasWindowDecorations then
    return x, y
  end
  return x - BORDER_WIDTH, y - BORDER_WIDTH - BAR_HEIGHT
end

---@param key love.KeyConstant
---@param scancode love.Scancode
---@param isRepeat boolean
function Widget:key(key, scancode, isRepeat)
end
function Widget:textInput(t)
end
function Widget:eatsInputs()
  return false
end

function Widget:testPoint(x, y)
  if not self:pointInside(x, y) then
    return WidgetPointState.None
  end

  if not self.hasWindowDecorations then
    return WidgetPointState.Inside
  end

  x, y = self:translateLocal(x, y)
  x, y = self:translateInside(x, y)

  if x >= 0 and x <= self.width and y <= self.height then
    if y >= 0 then
      return WidgetPointState.Inside
    else
      return WidgetPointState.Bar
    end
  end

  return WidgetPointState.None
end

function Widget:click(x, y, button)
end

function Widget:clickFrame(x, y, button)
  local state = self:testPoint(x, y)

  x, y = self:translateLocal(x, y)
  x, y = self:translateInside(x, y)

  if state == WidgetPointState.Bar then
    if button == 1 and x > (self.width - BAR_HEIGHT) then
      self.delete = true
    end
  elseif state == WidgetPointState.Inside then
    self:click(x, y, button)
  end
end

function Widget:move(x, y)
end

function Widget:moveFrame(x, y)
  local state = self:testPoint(x, y)

  x, y = self:translateLocal(x, y)
  x, y = self:translateInside(x, y)

  if state == WidgetPointState.Inside then
    self:move(x, y)
  end
end

function Widget:draw()
  love.graphics.setColor(colors.background:unpack())
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
end

function Widget:drawFrame()
  love.graphics.push()

  love.graphics.translate(self.x, self.y)

  if self.hasWindowDecorations then
    love.graphics.setColor(colors.border:unpack())
    love.graphics.setLineWidth(BORDER_WIDTH)
    love.graphics.rectangle('fill', 0, 0, self.width + BORDER_WIDTH * 2, self.height + BAR_HEIGHT + BORDER_WIDTH * 2, colors.borderRadius, colors.borderRadius)

    if self.focused then
      love.graphics.setColor(colors.windowFocused:unpack())
    else
      love.graphics.setColor(colors.window:unpack())
    end

    love.graphics.rectangle('fill', BORDER_WIDTH, BORDER_WIDTH, self.width, BAR_HEIGHT, colors.borderRadius, colors.borderRadius)

    love.graphics.setFont(fonts.inter_16)
    local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
    local hovered = my > 0 and my <= BAR_HEIGHT and mx > self.width - BAR_HEIGHT and mx < self.width
    if hovered then
      love.graphics.setColor(colors.text:unpack())
    else
      love.graphics.setColor(colors.textTertiary:unpack())
    end
    love.graphics.printf('x', self.width - BAR_HEIGHT, BAR_HEIGHT/2 - fonts.inter_16:getHeight()/2, BAR_HEIGHT, 'center')
    --local crossScale = BAR_HEIGHT / crossIcon:getHeight()
    --love.graphics.draw(crossIcon, BORDER_WIDTH + self.width - BAR_HEIGHT/2, BORDER_WIDTH + BAR_HEIGHT/2, 0, crossScale, crossScale, crossIcon:getWidth()/2, crossIcon:getWidth()/2)

    love.graphics.setFont(fonts.inter_12)

    if self.title then
      if self.focused then
        love.graphics.setColor((colors.windowFocusedText or colors.text):unpack())
      else
        love.graphics.setColor((colors.windowText or colors.textSecondary):unpack())
      end
      love.graphics.printf(self.title, BORDER_WIDTH, round(BAR_HEIGHT/2 - fonts.inter_12:getHeight()/2), self.width, 'center')
    end
  end

  love.graphics.push()

  if self.hasWindowDecorations then
    love.graphics.translate(BORDER_WIDTH, BAR_HEIGHT + BORDER_WIDTH)
  end

  self:draw()

  love.graphics.pop()

  love.graphics.pop()
end

---@type Widget[]
local widgets = { }

---@param w Widget
function openWidget(w, centered)
  self.update()
  if widgets[#widgets] then
    widgets[#widgets]:loseFocus(w)
    widgets[#widgets].focused = false
  end
  table.insert(widgets, w)
  w:focus()
  w.focused = true
  if centered then
    w.x = love.graphics.getWidth()/2 - w.width/2
    w.y = love.graphics.getHeight()/2 - w.height/2
  end
  self.update()
end

local InfobarWidget = require 'src.widgets.infobar'
local ActionBarWidget = require 'src.widgets.actionbar'
local MinimapWidget = require 'src.widgets.minimap'

---@type Widget?
local draggingWidget = nil
---@type number, number
local dragX, dragY = nil, nil

widgets = { InfobarWidget(), ActionBarWidget(), MinimapWidget(sw, 0) }

function getWidgets()
  return widgets
end

function self.update()
  for i = #widgets, 1, -1 do
    local widget = widgets[i]
    widget:update()
    if widget.delete then
      table.remove(widgets, i)
      if i > #widgets and #widgets ~= 0 then
        widgets[#widgets]:focus()
        widgets[#widgets].focused = true
      end
    end
  end
end
function self.callEvent(event)
  for _, widget in ipairs(widgets) do widget:event(event) end
end

function self.draw()
  for _, widget in ipairs(widgets) do
    widget:drawFrame()
  end
end

function self.eatsInputs()
  if widgets[#widgets] then
    return widgets[#widgets]:eatsInputs()
  end
end

---@param w Widget
local function clampWidget(w)
  local bx1, by1, bx2, by2 = w:getBoundingBox()
  w.x, w.y =
    clamp(w.x, w.x - bx1, sw + (w.x - bx2)),
    -- +24 to account for action bar
    clamp(w.y, w.y - by1 + 24, sh + (w.y - by2))
end

function self.mousepressed(x, y, button)
  for i = #widgets, 1, -1 do
    local widget = widgets[i]

    local res = widget:testPoint(x, y)

    if res ~= WidgetPointState.None then
      -- move to front
      if i ~= #widgets and not widget.ignoreFocus then
        table.remove(widgets, i)
        widgets[#widgets]:loseFocus(widget)
        widgets[#widgets].focused = false
        table.insert(widgets, widget)
        widget:focus()
        widget.focused = true
      end

      widget:clickFrame(x, y, button)

      if button == 1 and (res == WidgetPointState.Bar or widget.dragAnywhere) and widget.isMovable then
        draggingWidget = widget
        dragX, dragY = x - widget.x, y - widget.y
        widget.dragged = true
      end

      self.update()

      return true
    end
  end
end
function self.mousemoved(x, y)
  if draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
    clampWidget(draggingWidget)
  end
  for _, widget in ipairs(widgets) do
    widget:moveFrame(x, y)
  end
  self.update()
end
function self.mousereleased(x, y, button)
  if button == 1 and draggingWidget then
    draggingWidget.x, draggingWidget.y = x - dragX, y - dragY
    clampWidget(draggingWidget)
    draggingWidget.dragged = false
    draggingWidget = nil
    return true
  end
end
function self.textinput(t)
  if widgets[#widgets] then
    widgets[#widgets]:textInput(t)
  end
end
function self.keypressed(key, scancode, isRepeat)
  if widgets[#widgets] then
    return widgets[#widgets]:key(key, scancode, isRepeat)
  end
end

return self