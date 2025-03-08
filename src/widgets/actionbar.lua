local edit       = require 'src.edit'
local logs       = require 'src.logs'
local config     = require 'src.config'
local colors     = require 'src.colors'
local waveform   = require 'src.waveform'
local conductor  = require 'src.conductor'
local xdrvColors = require 'src.xdrvcolors'
local filesystem = require 'src.filesystem'
local exxdriver  = require 'src.exxdriver'
local json       = require 'lib.json'

local ContextWidget = require 'src.widgets.context'
local MetadataWidget = require 'src.widgets.metadata'
local AboutWidget = require 'src.widgets.about'
local CatjamWidget = require 'src.widgets.catjam'
local UITestWidget = require 'src.widgets.uitest'

local glyphsList = require 'assets.sprites.controller'

---@class ActionBarWidget : Widget
local ActionBarWidget = Widget:extend()

local HEIGHT = 24
local GAP = 14
local MARGIN = GAP / 2

---@type CatjamWidget?
local catjam = nil

---@type { [1]: string, [2]: fun(): ContextWidgetEntry }[]
local items = {
  { 'File', function()
    return {
      { 'Open',        function() chart.openChart()  end, bind = keybinds.binds.open },
      { 'Recent files', hover = function(self, i)
        local entries = {}
        for _, path in ipairs(config.config.recent) do
          table.insert(entries, { path, function() chart.openPath(path) end })
        end
        if #entries == 0 then
          table.insert(entries, { 'No recent files..' })
        end
        self:openChild(i, ContextWidget(0, 0, entries))
      end, expandable = true },
      { 'Close',       function() chart.loaded = false; chart.chart = nil; chart.metadata = nil; chart.loadedScript = nil; end, disabled = not chart.loaded },
      {},
      { 'Save',        function() chart.quickSave()  end, bind = keybinds.binds.quicksave, disabled = not chart.loaded },
      { 'Save as...',  function() chart.saveChart()  end, bind = keybinds.binds.save,      disabled = not chart.loaded },
      { 'Open in file browser', function() love.system.openURL('file://' .. chart.chartDir) end, disabled = not chart.chartDir },
      { 'Reload', function()
        chart.reload()
      end, disabled = not chart.chartLocation, bind = keybinds.binds.reload },
      { 'Import',   hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { '.SM/.SSC file', function() chart.importMenu('sm,ssc') end },
        }))
      end, expandable = true },
      {},
      { 'Metadata...', function() openWidget(MetadataWidget(), true) end, disabled = not chart.loaded },
      {},
      { 'Exit',        function() love.event.quit(0) end}
    }
  end},
  { 'View', function()
    return {
      { 'Preview mode', function()
        config.config.previewMode = not config.config.previewMode
        config.save()
        events.redraw()
      end, toggle = true, value = config.config.previewMode },
      { 'CMod', function()
        config.config.cmod = not config.config.cmod
        config.save()
        events.redraw()
      end, toggle = true, value = config.config.cmod },
      { 'Controller glyphs...', hover = function(self, i)
        local entries = {}
        table.insert(entries, {
          'None', function()
            config.config.controllerGlyphs = ''
            config.save()
            events.redraw()
          end,
          toggle = true, value = config.config.controllerGlyphs == ''
        })
        for _, layout in ipairs(glyphsList) do
          table.insert(entries, {
            titleCase(layout), function()
              config.config.controllerGlyphs = layout
              config.save()
              events.redraw()
            end,
            toggle = true, value = config.config.controllerGlyphs == layout
          })
        end
        self:openChild(i, ContextWidget(0, 0, entries))
      end, expandable = true },
      { 'View...', hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { 'Chart',       function() config.config.view.chart                = not config.config.view.chart;         config.save(); events.redraw() end,
          toggle = true, value = config.config.view.chart },
          { 'Drifts',      function() config.config.view.drifts               = not config.config.view.drifts;        config.save(); events.redraw() end,
          toggle = true, value = config.config.view.drifts },
          { 'Checkpoints', function() config.config.view.checkpoints          = not config.config.view.checkpoints;   config.save(); events.redraw() end,
          toggle = true, value = config.config.view.checkpoints },
          { 'Unsupported events', function() config.config.view.invalidEvents = not config.config.view.invalidEvents; config.save(); events.onEventsModify() end,
          toggle = true, value = config.config.view.invalidEvents },
        }))
      end, expandable = true },
    }
  end },
  { 'Edit', function()
    return {
      { 'Undo',  function() edit.undo()  end, bind = keybinds.binds.undo, disabled = #chart.history <= 1 },
      { 'Redo',  function() edit.redo()  end, bind = keybinds.binds.redo, disabled = #chart.future == 0 },
      {},
      { 'Cut',   function() edit.cut()   end, bind = keybinds.binds.cut },
      { 'Copy',  function() edit.copy()  end, bind = keybinds.binds.copy },
      { 'Paste', function() edit.paste() end, bind = keybinds.binds.paste, disabled = not edit.hasSomethingToPaste() },
      {},
      { 'Mirror',   hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { 'Horizontally', function() edit.mirrorSelection(edit.MirrorType.Horizontal) end },
          { 'Vertically',   function() edit.mirrorSelection(edit.MirrorType.Vertical)   end },
          { 'Both',         function() edit.mirrorSelection(edit.MirrorType.Both)       end },
        }))
      end, expandable = true },
      {},
      { 'Select All', function() edit.selectAll() end, bind = keybinds.binds.selectAll },
      { 'Delete',     function() edit.deleteKey() end, bind = keybinds.binds.delete, disabled = #edit.selection == 0 },
    }
  end},
  { 'Options', function()
    local vsync = love.window.getVSync()
    return {
      { 'Beat tick', function()
        config.config.beatTick = not config.config.beatTick
        logs.log('Beat tick: ' .. (config.config.beatTick and 'ON' or 'OFF'))
      end, toggle = true, value = config.config.beatTick, bind = keybinds.binds.beatTick },
      { 'Note tick', function()
        config.config.noteTick = not config.config.noteTick
        logs.log('Note tick: ' .. (config.config.noteTick and 'ON' or 'OFF'))
      end, toggle = true, value = config.config.noteTick, bind = keybinds.binds.noteTick },
      {},
      { 'VSync', function()
        local newVsync = 1 - vsync
        logs.log('VSync: ' .. ((newVsync == 1) and 'ON' or 'OFF'))
        love.window.setVSync(newVsync)
        config.config.vsync = newVsync == 1
        config.save()
      end, toggle = true, value = vsync == 1 },
      { 'Disable multithreading', function()
        config.config.noMultithreading = not config.config.noMultithreading
        logs.log('Multithreading: ' .. (config.config.noMultithreading and 'OFF' or 'ON'))
        if config.config.noMultithreading then
          logs.log('Only touch this if you know what you\'re doing!')
        end
      end, toggle = true, value = config.config.noMultithreading, disabled = MACOS },
      {},
      { 'Theme', hover = function(self, i)
        local entries = {}
        for _, theme in ipairs(colors.getSchemes()) do
          table.insert(entries, { theme.name, function()
            colors.setScheme(theme.key)
            config.config.theme = theme.key
            config.save()
          end, toggle = true, value = colors.getScheme() == theme.key })
        end
        self:openChild(i, ContextWidget(0, 0, entries))
      end, expandable = true },
      { 'Colors', hover = function(self, i)
        local entries = {}
        for _, theme in ipairs(xdrvColors.schemes) do
          table.insert(entries, { theme.name, function()
            xdrvColors.setScheme(theme.name)
            config.config.xdrvColors = theme.name
            config.save()
          end, toggle = true, value = xdrvColors.scheme.name == theme.name })
        end
        -- a little ugly; adds the little break after the first theme
        table.insert(entries, 2, {})

        table.insert(entries, {})
        table.insert(entries, { 'Custom', function()
          xdrvColors.setScheme('custom')
          config.config.xdrvColors = 'custom'
          config.save()
        end, toggle = true, value = xdrvColors.scheme.name == 'Custom' })
        table.insert(entries, { 'Import from JSON...', function()
          filesystem.openDialog(exxdriver.getColorSchemePath() .. '/', 'json', function(path)
            if not path then return end
            local file, err = io.open(path, 'r')
            if not file then
              logs.warn(err)
              return
            end
            local raw = file:read('*a')
            file:close()

            local data = json.decode(raw)
            xdrvColors.setCustom(data.Colors)
            xdrvColors.setScheme('custom')

            config.config.xdrvColors = 'custom'
            config.save()
          end)
        end })

        self:openChild(i, ContextWidget(0, 0, entries))
      end, expandable = true },
      { 'Waveform (EXPERIMENTAL)', function()
        config.config.waveform = not config.config.waveform
        if config.config.waveform and conductor.fileData then
          waveform.init(conductor.fileData)
        else
          waveform.clear()
        end
        config.save()
      end, toggle = true, value = config.config.waveform },
      { 'Double-res waveform', function()
        config.config.doubleResWaveform = not config.config.doubleResWaveform
        if config.config.waveform and conductor.fileData then
          waveform.init(conductor.fileData)
        end
        config.save()
      end, toggle = true, value = config.config.doubleResWaveform },
      { 'Waveform opacity', function(value)
        config.config.waveformOpacity = value
      end, slider = true, value = config.config.waveformOpacity },
      { 'Waveform brightness', function(value)
        config.config.waveformBrightness = value
      end, slider = true, value = config.config.waveformBrightness },
      {},
      { 'Cat', function()
        if not catjam or catjam.delete then
          catjam = CatjamWidget(32, 32)
          openWidget(catjam)
        else
          catjam.delete = true
          catjam = nil
        end
      end, toggle = true, value = not (not catjam or catjam.delete) },
    }
  end},
  { 'Help', function()
    return {
      { 'View keybinds', function() edit.viewBinds = not edit.viewBinds end, bind = keybinds.binds.viewBinds },
      {},
      { 'UI Test',         function() openWidget(UITestWidget(150, 150)) end },
      { 'About',         function() openWidget(AboutWidget(150, 150)) end },
      {},
      { 'Debug', hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { '!! No support will be offered !!', disabled = true },
          { 'Use the options here at your own risk', disabled = true },
          { 'Undo history', function() config.config.debug.undoHistory = not config.config.debug.undoHistory; config.save() end,
          toggle = true, value = config.config.debug.undoHistory },
          { 'Mods display', function() config.config.debug.modsDisplay = not config.config.debug.modsDisplay; config.save() end,
          toggle = true, value = config.config.debug.modsDisplay },
          { 'Ignore draw cache', function() config.config.debug.alwaysIgnoreCache = not config.config.debug.alwaysIgnoreCache; config.save() end,
          toggle = true, value = config.config.debug.alwaysIgnoreCache },
        }))
      end, expandable = true },
    }
  end},
}

function ActionBarWidget:new()
  ActionBarWidget.super.new(self, 0, 0)
  self.isMovable = false
  self.hasWindowDecorations = false
  self.resizable = false
  self.height = HEIGHT
  self.ignoreFocus = true

  ---@type love.Text[]
  self.texts = {}
  for _, item in ipairs(items) do
    local text = love.graphics.newText(fonts.inter_12, item[1])
    table.insert(self.texts, text)
  end
  self.items = items

  ---@type ContextWidget
  self.open = nil
  self.openIdx = nil
end

function ActionBarWidget:update()
  if self.open and self.open.delete then
    self.open = nil
    self.openIdx = nil
  end
end

function ActionBarWidget:mouse(x, y, click)
  local tx = MARGIN
  for i, item in ipairs(self.texts) do
    if x < (tx + item:getWidth() + GAP/2) then
      if click and self.open and self.openIdx == i then
        self.open.delete = true
        self.open = nil
        self.openIdx = nil
        return
      end

      if i == self.openIdx then break end

      local widget = ContextWidget(tx - GAP/2, self.y + self.height, self.items[i][2]())
      openWidget(widget)
      self.open = widget
      self.openIdx = i
      return
    end
    tx = tx + item:getWidth() + GAP
  end
end
function ActionBarWidget:move(x, y)
  if self.open then
    self:mouse(x, y)
  end
end
function ActionBarWidget:click(x, y, button)
  if button ~= 1 then return end
  self:mouse(x, y, true)
end

function ActionBarWidget:draw()
  self.width = love.graphics.getWidth()
  self.height = HEIGHT

  love.graphics.setColor(colors.element:unpack())
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  local x = MARGIN
  for i, item in ipairs(self.texts) do
    local open = self.openIdx == i

    if open then
      love.graphics.setColor(colors.hover:unpack())
      love.graphics.rectangle('fill', x - GAP/2, 0, item:getWidth() + GAP, HEIGHT)
    end
    love.graphics.setColor(colors.text:unpack())
    if open then
      love.graphics.setColor((colors.hoverText or colors.text):unpack())
    end

    love.graphics.draw(item, round(x), round(HEIGHT/2 - item:getHeight()/2))
    x = x + item:getWidth() + GAP
  end
end

return ActionBarWidget