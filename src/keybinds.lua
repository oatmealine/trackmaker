local edit   = require 'src.edit'
local logs   = require 'src.logs'
local config = require 'src.config'
local self = {}

---@class Keybind
---@field ctrl boolean?
---@field shift boolean?
---@field viewOnly boolean?
---@field writeOnly boolean?
---@field keys love.Scancode[]?
---@field keyCodes love.KeyConstant[]?
---@field name string?
---@field canRepeat boolean?
---@field alwaysUsable boolean?
---@field trigger fun()?

---@type table<string, Keybind>
self.binds = {
  open = {
    name = 'Open',
    ctrl = true,
    viewOnly = true,
    keys = { 'o' },
    trigger = function()
      chart.openChart()
    end
  },
  save = {
    name = 'Save as...',
    ctrl = true,
    shift = true,
    keys = { 's' },
    trigger = function()
      chart.saveChart()
    end
  },
  quicksave = {
    name = 'Save',
    ctrl = true,
    keys = { 's' },
    trigger = function()
      chart.quickSave()
    end
  },
  cut = {
    name = 'Cut',
    ctrl = true,
    writeOnly = true,
    keyCodes = { 'x' },
    trigger = edit.cut,
  },
  copy = {
    name = 'Copy',
    ctrl = true,
    writeOnly = true,
    keyCodes = { 'c' },
    trigger = edit.copy,
  },
  paste = {
    name = 'Paste',
    ctrl = true,
    writeOnly = true,
    keyCodes = { 'v' },
    trigger = edit.paste,
  },
  viewBinds = {
    name = 'View keybinds',
    keys = { 'f11' },
    alwaysUsable = true,
    trigger = function()
      edit.viewBinds = not edit.viewBinds
    end
  },
  dumpChart = {
    name = 'Dump chart to log',
    ctrl = true,
    keys = { 'l' },
    trigger = function()
      logs.logFile(pretty(chart.chart))
      logs.log('Wrote chart to trackmaker.log')
    end
  },
  dumpChartClipboard = {
    name = 'Dump chart to clipboard',
    ctrl = true,
    shift = true,
    keys = { 'l' },
    trigger = function()
      love.system.setClipboardText(pretty(chart.chart))
      logs.log('Wrote chart to clipboard')
    end
  },
  cycleMode = {
    name = 'Cycle mode',
    keys = { 'tab' },
    trigger = function()
      edit.cycleMode()
    end
  },
  exitWrite = {
    name = 'Exit write mode',
    keys = { 'escape' },
    writeOnly = true,
    trigger = function()
      edit.write = false
    end
  },
  decreaseVolume = {
    name = 'Decrease volume',
    keys = { 'down' },
    shift = true,
    trigger = function()
      config.config.volume = math.max(config.config.volume - 0.05, 0)
      logs.log('Volume set to ' .. round(config.config.volume * 100) .. '%')
    end,
  },
  increaseVolume = {
    name = 'Increase volume',
    keys = { 'up' },
    shift = true,
    trigger = function()
      config.config.volume = math.min(config.config.volume + 0.05, 1)
      logs.log('Volume set to ' .. round(config.config.volume * 100) .. '%')
    end,
  },
  beatTick = {
    name = 'Beat tick',
    keys = { 'f3' },
    trigger = function()
      config.config.beatTick = not config.config.beatTick
      logs.log('Beat tick: ' .. (config.config.beatTick and 'ON' or 'OFF'))
    end,
  },
  noteTick = {
    name = 'Note tick',
    keys = { 'f4' },
    trigger = function()
      config.config.noteTick = not config.config.noteTick
      logs.log('Note tick: ' .. (config.config.noteTick and 'ON' or 'OFF'))
    end,
  },
}

local function formatKey(key)
  return string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

---@param bind Keybind
function self.formatBind(bind)
  local segments = {}
  if bind.ctrl then table.insert(segments, 'Ctrl') end
  if bind.shift then table.insert(segments, 'Shift') end
  for _, key in ipairs(bind.keys or {}) do
    table.insert(segments, formatKey(key))
  end
  for _, key in ipairs(bind.keyCodes or {}) do
    table.insert(segments, formatKey(key))
  end
  return table.concat(segments, '+')
end

return self