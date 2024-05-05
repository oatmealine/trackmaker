local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local UIWidget  = require 'src.widgets.ui'

local logs      = require 'src.logs'

---@class ChartSettingsWidget : UIWidget
local ChartSettingsWidget = UIWidget:extend()

local WIDTH = 170
local HEIGHT = 190

function ChartSettingsWidget:new(x, y)
  ChartSettingsWidget.super.new(self, x, y, Container(Container.placeFormLike({
    { Label(0, 0, 'Keyboard Only'),        { Checkmark(0, 0, function(_, value)
      chart.metadata.isKeyboardOnly = value
      chart.markDirty()
    end, chart.metadata.isKeyboardOnly ) } },
    { Label(0, 0, 'Original'),             { Checkmark(0, 0, function(_, value)
      chart.metadata.isOriginal = value
      chart.markDirty()
    end, chart.metadata.isOriginal ) } },
    { Label(0, 0, 'Disable Leaderboards'), { Checkmark(0, 0, function(_, value)
      chart.metadata.disableLeaderboardUploading = value
      chart.markDirty()
    end, chart.metadata.disableLeaderboardUploading ) } },
    { Label(0, 0, 'RPC Hidden'),           { Checkmark(0, 0, function(_, value)
      chart.metadata.rpcHidden = value
      chart.markDirty()
    end, chart.metadata.rpcHidden ) } },
    { Label(0, 0, 'Boss'),                 { Checkmark(0, 0, function(_, value)
      chart.metadata.chartBoss = value
      chart.markDirty()
    end, chart.metadata.chartBoss ) } },
    { Label(0, 0, 'Flash Track'),          { Checkmark(0, 0, function(_, value)
      chart.metadata.isFlashTrack = value
      chart.markDirty()
    end, chart.metadata.isFlashTrack ) } },
  }, WIDTH)))
  self.width = WIDTH
  self.height = HEIGHT
  self.title = 'Chart Settings'
end

return ChartSettingsWidget