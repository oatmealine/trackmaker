local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local Select    = require 'src.ui.select'
local UIWidget  = require 'src.widgets.ui'

---@class ImportSMWidget : UIWidget
local ImportSMWidget = UIWidget:extend()

function ImportSMWidget:new(chart, filepath, callback)
  local chartNames = {}
  for _, c in ipairs(chart.NOTES) do
    table.insert(chartNames, (c.credit ~= '' and c.credit or 'Chart') .. ' [' .. c.type .. ', ' .. c.difficulty .. ']')
  end
  self.chartNames = chartNames

  self.chart = chart
  self.filepath = filepath

  self.callback = callback

  self.chartIdx = 1
  self.styleIdx = 1

  ImportSMWidget.super.new(self, 0, 0, self:getContainer(), self.width)

  self.title = 'Import SM/SSC'
  self.width = 280
  self.height = 240
end

function ImportSMWidget:getContainer()
  return Container(Container.placeRows({
    {
      Label(0, 0, 'Chart')
    },
    {
      Select(0, 0, self.chartNames, function(i) self:setChart(i) end, self.chartIdx)
    },
    {
      Label(0, 0, 'Style')
    },
    {
      Checkmark(0, 0, function() self:setStyle(1) end, self.styleIdx == 1), Label(0, 0, 'Lasdl;"R<>')
    },
    {
      Checkmark(0, 0, function() self:setStyle(2) end, self.styleIdx == 2), Label(0, 0, '<Lasdl;"R>')
    },
    {
      Checkmark(0, 0, function() self:setStyle(3) end, self.styleIdx == 3), Label(0, 0, 'asdl;"LR<>')
    },
    {},
    {
      Label(0, 0, #self.chart.NOTES[self.chartIdx].notes .. ' notes'), Button(0, 0, 'Import', function() self:finish() end)
    },
  }, self.width))
end

function ImportSMWidget:setChart(i)
  self.chartIdx = i
  self.container = self:getContainer()
end

function ImportSMWidget:setStyle(i)
  self.styleIdx = i
  self.container = self:getContainer()
end

function ImportSMWidget:finish()
  self.delete = true

  self.callback(self.chart, self.filepath, self.chart.NOTES[self.chartIdx], self.styleIdx)
end

return ImportSMWidget