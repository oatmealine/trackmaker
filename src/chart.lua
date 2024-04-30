local self = {}

local xdrv = require 'lib.xdrv'
local nfd = require 'nfd'
local conductor = require 'src.conductor'
local logs      = require 'src.logs'

self.loaded = false
---@type XDRVEvent[]
self.chart = nil
---@type XDRVMetadata
self.metadata = nil
---@type string
self.chartDir = nil
---@type string
self.chartLocation = nil

self.dirty = false

function self.diffMark()
  return '[' .. xdrv.formatDifficultyShort(self.metadata.chartDifficulty) .. lpad(tostring(self.metadata.chartLevel), 2, '0') .. ']'
end

local function updateTitle()
  if self.loaded then
    local dirtyMark = ''
    if self.dirty then dirtyMark = ' ·' end
    love.window.setTitle(
      self.metadata.musicTitle ..
      ' ' .. self.diffMark() ..
      ' - trackmaker' .. dirtyMark
    )
  else
    love.window.setTitle('trackmaker')
  end
end

function self.openChart()
  local filepath = nfd.open('xdrv')

  if not filepath then return end

  local file, err = io.open(filepath, 'r')
  if not file then
    print(err)
    return
  end
  local data = file:read('*a')
  file:close()

  local loaded = xdrv.deserialize(data)
  self.chart = loaded.chart or {}
  -- sanity check
  table.sort(self.chart, function (a, b) return a.beat < b.beat end)
  self.chartLocation = filepath
  self.metadata = loaded.metadata
  self.chartDir = string.gsub(filepath, '([/\\])[^/\\]+$', '%1')
  conductor.reset()
  conductor.loadFromChart({ chart = self.chart, metadata = self.metadata }, self.chartDir)

  self.loaded = true
  updateTitle()

  logs.log('Loaded chart ' .. self.metadata.musicTitle .. ' ' .. self.diffMark())
end

local function save(filepath)
  local file, err = io.open(filepath, 'w')
  if not file then
    print(err)
    return
  end
  file:write('// Made with trackmaker v' .. release.version .. '\n' .. xdrv.serialize({ metadata = self.metadata, chart = self.chart }))
  file:close()
  self.dirty = false
  updateTitle()

  logs.log('Saved chart to ' .. filepath)
end

---@param m XDRVMetadata
local function makeChartFilename(m)
  return xdrv.formatDifficulty(m.chartDifficulty) .. '.xdrv'
end

---@param event XDRVEvent
---@return number?
function self.findEvent(event)
  for i, ev in ipairs(self.chart) do
    if ev.beat > event.beat then
      return
    end
    if ev.beat == event.beat and looseComp(event, ev) then
      return i
    end
  end
end

function self.removeEvent(i)
  self.markDirty()
  table.remove(self.chart, i)
end

---@param event XDRVEvent
function self.placeEvent(event)
  self.markDirty()
  for i, ev in ipairs(self.chart) do
    if ev.beat > event.beat then
      table.insert(self.chart, i - 1, event)
      return
    end
  end
  table.insert(self.chart, event)
end

function self.saveChart()
  if not self.chart then return end

  local filepath = nfd.save('xdrv', self.chartDir .. '/' .. makeChartFilename(self.metadata))

  if not filepath then return end
  save(filepath)
end

function self.quickSave()
  if not self.chart then return end
  save(self.chartLocation)
end

function self.markDirty()
  self.dirty = true
  updateTitle()
end

updateTitle()

return self