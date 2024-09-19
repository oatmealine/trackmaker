local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local Select    = require 'src.ui.select'
local UIWidget  = require 'src.widgets.ui'
local xdrv      = require 'lib.xdrv'

local logs      = require 'src.logs'

---@class ChartSettingsWidget : UIWidget
local ChartSettingsWidget = UIWidget:extend()

local WIDTH = 220
local HEIGHT = 220

function ChartSettingsWidget:new(x, y)
  ChartSettingsWidget.super.new(self, x, y, self:getContainer())
  self.width = WIDTH
  self.height = HEIGHT
  self.title = 'Chart Settings'
end

function ChartSettingsWidget:event(name)
  if name == 'chartUpdate' then
    self.container = self:getContainer()
  end
end

function ChartSettingsWidget:getContainer()
  local metadata = chart.metadata or {}

  local elems = Container.placeFormLike({
    { Label(0, 0, 'Keyboard Only'),        { Checkmark(0, 0, function(_, value)
      chart.metadata.isKeyboardOnly = value
      chart.markDirty()
    end, metadata.isKeyboardOnly ) } },
    { Label(0, 0, 'Original'),             { Checkmark(0, 0, function(_, value)
      chart.metadata.isOriginal = value
      chart.markDirty()
    end, metadata.isOriginal ) } },
    { Label(0, 0, 'Disable Leaderboards'), { Checkmark(0, 0, function(_, value)
      chart.metadata.disableLeaderboardUploading = value
      chart.markDirty()
    end, metadata.disableLeaderboardUploading ) } },
    { Label(0, 0, 'RPC Hidden'),           { Checkmark(0, 0, function(_, value)
      chart.metadata.rpcHidden = value
      chart.markDirty()
    end, metadata.rpcHidden ) } },
    { Label(0, 0, 'Boss'),                 { Checkmark(0, 0, function(_, value)
      chart.metadata.chartBoss = value
      chart.markDirty()
    end, metadata.chartBoss ) } },
    { Label(0, 0, 'Flash Track'),          { Checkmark(0, 0, function(_, value)
      chart.metadata.isFlashTrack = value
      chart.markDirty()
    end, metadata.isFlashTrack ) } },
    {
      Label(0, 0, 'Stage Background'),
      {
        Select(0, 0, xdrv.STAGE_BACKGROUNDS, function(value)
          chart.metadata.stageBackground = xdrv.STAGE_BACKGROUNDS[value]
          chart.markDirty()
        end, findIndex(xdrv.STAGE_BACKGROUNDS, chart.metadata.stageBackground)),
      }
    }
  }, WIDTH)

  if not chart.loaded then
    for _, elem in ipairs(elems) do
      elem.disabled = true
    end
  end

  return Container(elems)
end

return ChartSettingsWidget