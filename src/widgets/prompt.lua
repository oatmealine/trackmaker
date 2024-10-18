local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Label     = require 'src.ui.label'
local UIWidget  = require 'src.widgets.ui'

---@class PromptWidget : UIWidget
local PromptWidget = UIWidget:extend()

local WIDTH = 300

---@alias PromptAction { text: string, click: fun():nil }

---@param message string
---@param actions PromptAction[]
function PromptWidget:new(message, actions)
  ---@type Label
  local label = Label(0, 0, message)
  label:setWrapWidth(WIDTH - 10)
  label:setAlign('center')

  local buttons = {}
  for _, action in ipairs(actions) do
    local button = Button(0, 0, action.text, function()
      action.click()
      self.delete = true
    end)
    table.insert(buttons, button)
  end

  PromptWidget.super.new(self, 0, 0, Container(Container.placeRows({
    { label }, buttons
  }, WIDTH, true)))
  self.width = WIDTH
  self.height = 80
end

return PromptWidget