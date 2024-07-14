local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local UIWidget  = require 'src.widgets.ui'

---@class CheckpointPromptWidget : UIWidget
local CheckpointPromptWidget = UIWidget:extend()

function CheckpointPromptWidget:new(beat, name)
  self.beat = beat
  self.checkName = name or ''

  CheckpointPromptWidget.super.new(self, 0, 0, Container(Container.placeRows({
    {
      Label(0, 0, 'Beat'), Textfield(0, 0, 40, self.beat, function(value) self.beat = tonumber(value) end),
    },
    {
      Label(0, 0, 'Name'), Textfield(0, 0, 140, self.checkName, function(value) self.checkName = value self:updateName() end),
    },
    {
      Button(40, 10, 'Place', function() self:place(true) self.delete = true end),
      Button(40, 10, 'Delete', function() self:place(false) self.delete = true end),
    },
  }, self.width)))

  self.title = 'Place Checkpoint'
  self.width = 220
  self.height = 100

  self:updateName()
end

function CheckpointPromptWidget:updateName()
  self.checkName = self.container.children[4] --[[@as Textfield]].value
  self.container.children[5].disabled = self.checkName == ''
end
function CheckpointPromptWidget:update()
  CheckpointPromptWidget.super.update(self)
  self:updateName()
end
function CheckpointPromptWidget:textInput(t)
  CheckpointPromptWidget.super.textInput(self, t)
  self:updateName()
end

function CheckpointPromptWidget:place(shouldPlace)
  local existingCheckpoint = chart.findEventOfType(self.beat, 'checkpoint')
  if existingCheckpoint then
    chart.removeEvent(existingCheckpoint)
  end

  if shouldPlace then
    chart.placeEvent({
      beat = self.beat,
      checkpoint = self.checkName,
    })
  end
end

return CheckpointPromptWidget