local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'

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
  }, self.width))
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

return UITestWidget