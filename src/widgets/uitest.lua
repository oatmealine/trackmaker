local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local UIWidget  = require 'src.widgets.ui'

local logs      = require 'src.logs'

---@class UITestWidget : UIWidget
local UITestWidget = UIWidget:extend()

function UITestWidget:new(x, y)
  UITestWidget.super.new(self, x, y, Container(Container.placeRows({
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
  }, self.width)))
  self.width = 400
  self.height = 400
end

return UITestWidget