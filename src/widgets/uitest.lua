local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'

local logs      = require 'src.logs'

---@class UITestWidget : Widget
local UITestWidget = Widget:extend()

function UITestWidget:new(x, y)
  UITestWidget.super.new(self, x, y)
  self.width = 400
  self.height = 400

  ---@type Container
  self.container = Container(Container.placeRows({
    {
      Button(40, 10, 'test', function() logs.log('pressed') end),
    },
    {
      Checkmark(10, 10, function(_self, value) logs.log(tostring(value)) end),
      Label(0, 0, 'Enable the glogger')
    },
    {
      Textfield(0, 0, 100, 't', function(value) logs.log(value) end)
    },
  }, self.width))
end

function UITestWidget:loseFocus()
  self.container:loseFocus()
end

function UITestWidget:eatsInputs()
  return self.container:eatsInputs()
end

function UITestWidget:key(key, scancode, isRepeat)
  self.container:key(key, scancode, isRepeat)
end

function UITestWidget:click(x, y, button)
  self.container:click(x, y, button)
end
function UITestWidget:move(x, y)
  self.container:move(x, y)
end

function UITestWidget:update()
  self.container:update()
end

function UITestWidget:draw()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  self.container:draw()
end

function UITestWidget:textInput(t)
  self.container:textInput(t)
end

return UITestWidget