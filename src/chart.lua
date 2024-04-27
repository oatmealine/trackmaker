local self = {}

local xdrv = require 'lib.xdrv'
local nfd = require 'nfd'
local conductor = require 'src.conductor'

self.loaded = false
---@type XDRVEvent[]
self.chart = nil
---@type table<string, string>
self.metadata = nil
---@type string
self.chartDir = nil

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
  self.chart = loaded.chart
  self.metadata = loaded.metadata
  self.chartDir = string.gsub(filepath, '([/\\])[^/\\]+$', '%1')
  conductor.loadFromChart({ chart = self.chart, metadata = self.metadata }, self.chartDir)

  self.loaded = true
end

function self.saveChart()
  if not self.chart then return end

  local filepath = nfd.save('xdrv', self.chartDir .. '/' .. self.metadata.CHART_DIFFICULTY .. '.xdrv')

  if not filepath then return end

  local file, err = io.open(filepath, 'w')
  if not file then
    print(err)
    return
  end
  file:write('// Made with trackmaker v' .. release.version .. '\n' .. xdrv.serialize({ metadata = self.metadata, chart = self.chart }))
  file:close()
end

return self