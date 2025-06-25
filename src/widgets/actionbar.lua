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
local keybinds   = require 'src.keybinds'

local ContextWidget = require 'src.widgets.context'
local MetadataWidget = require 'src.widgets.metadata'
local AboutWidget = require 'src.widgets.about'
local CatjamWidget = require 'src.widgets.catjam'
local UITestWidget = require 'src.widgets.uitest'

local glyphsList = require 'assets.sprites.controller'

---@class ActionBarWidget : Widget
local ActionBarWidget = Widget:extend()

local HEIGHT = 24
ActionBarWidget.HEIGHT = 24
local GAP = 14
local MARGIN = GAP / 2

---@type CatjamWidget?
local catjam = nil

local glyphListEntries = {}

table.insert(glyphListEntries, {
  'None', click = function()
    config.config.controllerGlyphs = ''
    config.save()
    events.redraw()
  end,
  toggle = true, value = function() return config.config.controllerGlyphs == '' end
})
for _, layout in ipairs(glyphsList) do
  table.insert(glyphListEntries, {
    titleCase(layout), click = function()
      config.config.controllerGlyphs = layout
      config.save()
      events.redraw()
    end,
    toggle = true, value = function() return config.config.controllerGlyphs == layout end
  })
end

local schemesEntries = {}
for _, theme in ipairs(colors.getSchemes()) do
  table.insert(schemesEntries, { theme.name, click = function()
    colors.setScheme(theme.key)
    config.config.theme = theme.key
    config.save()
  end,
  toggle = true, value = function() return colors.getScheme() == theme.key end })
end

local notChartLoaded = function() return not chart.loaded end

-- todo: make these arguments a table?
local function toggle(t)
  local entry = deepcopy(t)
  entry.set = nil
  entry.get = nil
  entry.callback = nil

  entry.click = function()
    local new = not t.get()
    t.set(new)
    config.save()
    events.redraw()
    if t.callback then t.callback(new) end
  end
  entry.toggle = true
  entry.value = t.get

  return entry
end
local function toggleVerbose(t)
  local _set = t.set
  t.set = function(v)
    logs.log(t[1] .. ': ' .. (v and 'ON' or 'OFF'))
    return _set(v)
  end
  return toggle(t)
end

---@alias ActionBarItem { [1]: string?, [2]: ActionBarItem[], click: fun()?, bind: Keybind?, disabled: (fun(): boolean)?, value: (fun(): any)?, set: (fun(value: any): any)?, representedFile: string?, toggle: boolean?, slider: boolean?, getSubmenu: (fun(): ActionBarItem[])?, formatValue: (fun(value: number): string)? }

---@type ActionBarItem[]
ActionBarWidget.barItems = {
  { 'File',
    {
      { 'Open',         click = function()
        chart.openChart()
      end, bind = keybinds.binds.open },
      { 'Recent files', getSubmenu = function()
        local entries = {}
        for _, path in ipairs(config.config.recent) do
          table.insert(entries, { path, click = function() chart.openPath(path) end, representedFile = path })
        end
        if #entries == 0 then
          table.insert(entries, { 'No recent files..' })
        end
        return entries
      end },
      { 'Close',       click = function()
        chart.loaded = false
        chart.chart = nil
        chart.metadata = nil
        chart.loadedScripts = {}
      end, disabled = notChartLoaded },
      {},
      { 'Save',        click = function()
        chart.quickSave()
      end, disabled = notChartLoaded, bind = keybinds.binds.quicksave },
      { 'Save as...',  click = function()
        chart.saveChart()
      end, disabled = notChartLoaded, bind = keybinds.binds.save },
      { 'Open in file browser', click = function()
        love.system.openURL('file://' .. chart.chartDir)
      end, disabled = function() return not chart.chartDir end },
      { 'Reload', click = function()
        chart.reload()
      end,
      disabled = function() return not chart.chartLocation end,
      bind = keybinds.binds.reload },
      { 'Import',   {
        { '.SM/.SSC file', click = function() chart.importMenu('sm,ssc') end },
      }},
      {},
      { 'Metadata...', click = function()
        openWidget(MetadataWidget(), true)
      end, disabled = notChartLoaded },
      {},
      { 'Exit',        click = function()
        love.event.quit(0)
      end, bind = keybinds.binds.exit}
    }
  },
  { 'View',
    {
      toggle { 'Preview mode', get = function() return config.config.previewMode end, set = function(v) config.config.previewMode = v end },
      toggle { 'CMod', get = function() return config.config.cmod end, set = function(v) config.config.cmod = v end },
      { 'Controller glyphs...', glyphListEntries },
      { 'View...', {
        toggle { 'Chart',
          get = function() return config.config.view.chart end,
          set = function(v) config.config.view.chart = v end },
        toggle { 'Drifts',
          get = function() return config.config.view.drifts end,
          set = function(v) config.config.view.drifts = v end },
        toggle { 'Checkpoints',
          get = function() return config.config.view.checkpoints end,
          set = function(v) config.config.view.checkpoints = v end },
        toggle { 'Unsupported events',
          get = function() return config.config.view.invalidEvents end,
          set = function(v) events.onEventsModify() config.config.view.invalidEvents = v end },
      }},
    }
  },
  { 'Edit',
    {
      { 'Undo',  click = function()
        edit.undo()
      end, disabled = function() return #chart.history <= 1 end, bind = keybinds.binds.undo },
      { 'Redo',  click = function()
        edit.redo()
      end, disabled = function() return #chart.future == 0 end, bind = keybinds.binds.redo },
      {},
      { 'Cut',   click = function()
        edit.cut()
      end, bind = keybinds.binds.cut },
      { 'Copy',  click = function()
        edit.copy()
      end, bind = keybinds.binds.copy },
      { 'Paste', click = function()
        edit.paste()
      end, disabled = function() return not edit.hasSomethingToPaste() end, bind = keybinds.binds.paste },
      {},
      { 'Mirror', {
        { 'Horizontally', click = function() edit.mirrorSelection(edit.MirrorType.Horizontal) end },
        { 'Vertically',   click = function() edit.mirrorSelection(edit.MirrorType.Vertical)   end },
        { 'Both',         click = function() edit.mirrorSelection(edit.MirrorType.Both)       end },
      }},
      {},
      { 'Toggle mines',  click = function()
        edit.turnToMines()
      end, disabled = function() return #edit.selection == 0 end, bind = keybinds.binds.mines },
      {},
      { 'Select All', click = function() edit.selectAll() end, bind = keybinds.binds.selectAll },
      { 'Delete',     click = function() edit.deleteKey() end,
      disabled = function() return #edit.selection == 0 end,
      bind = keybinds.binds.delete },
    }
  },
  { 'Options', {
    toggleVerbose { 'Beat tick',
      get = function() return config.config.beatTick end,
      set = function(v) config.config.beatTick = v end,
      bind = keybinds.binds.beatTick },
    toggleVerbose { 'Note tick',
      get = function() return config.config.noteTick end,
      set = function(v) config.config.noteTick = v end,
      bind = keybinds.binds.noteTick },
    {},
    { 'VSync', click = function()
      local newVsync = 1 - love.window.getVSync()
      logs.log('VSync: ' .. ((newVsync == 1) and 'ON' or 'OFF'))
      love.window.setVSync(newVsync)
      config.config.vsync = newVsync == 1
      config.save()
    end, toggle = true, value = function() return love.window.getVSync() == 1 end },
    { 'Disable multithreading', click = function()
      config.config.noMultithreading = not config.config.noMultithreading
      logs.log('Multithreading: ' .. (config.config.noMultithreading and 'OFF' or 'ON'))
      if config.config.noMultithreading then
        logs.log('Only touch this if you know what you\'re doing!')
      end
    end,
    toggle = true, value = function() return MACOS or config.config.noMultithreading end,
    disabled = function() return MACOS end },
    {},
    { 'Theme', schemesEntries },
    { 'Fonts', getSubmenu = function()
      local entries = {}
      for _, font in ipairs(love.filesystem.getDirectoryItems('assets/fonts')) do
        local path = 'assets/fonts/' .. font
        local realDir = love.filesystem.getRealDirectory(path) .. '/' .. path
        if font ~= '.DS_Store' then
          table.insert(entries, { font, click = function()
            config.config.uiFont = font
            initFonts()
            events.redraw()
            config.save()
          end,
          representedFile = realDir,
          toggle = true,
          value = function() return config.config.uiFont == font end })
        end
      end
      if string.sub(config.config.uiFont, 1, 7) == 'file://' then
        table.insert(entries, { basename(config.config.uiFont), click = function()
          initFonts()
          events.redraw()
          config.save()
        end,
        representedFile = string.sub(config.config.uiFont, 8),
        toggle = true,
        value = function() return true end })
      end
      table.insert(entries, { 'Other...' , click = function()
        filesystem.openDialog('', 'ttf;otf', function(path)
          if not path then return end

          local ext = string.sub(path, -4)
          if ext ~= '.ttf' and ext ~= '.otf' then
            logs.warn('Only .ttf and .otf files are supported')
            return
          end
          if ext == '.otf' then
            logs.log('LÖVE support for .otf files is experimental, some features may not be supported')
          end

          config.config.uiFont = 'file://' .. path
          initFonts()
          events.redraw()
          config.save()
        end)
      end})
      table.insert(entries, {})
      local minFontSize = 6
      local maxFontSize = 18
      table.insert(entries, { 'Size', set = function(a)
        local fontSize = round(minFontSize + a * (maxFontSize - minFontSize))
        if fontSize ~= config.config.uiFontSize then
          config.config.uiFontSize = fontSize
          initFonts()
          events.redraw()
          config.save()
        end
      end, formatValue = function(a)
        return tostring(round(minFontSize + a * (maxFontSize - minFontSize)))
      end, slider = true, value = function()
        return (config.config.uiFontSize - minFontSize) / (maxFontSize - minFontSize)
      end })
      return entries
    end },
    { 'Colors', getSubmenu = function()
      local entries = {}
      for _, theme in ipairs(xdrvColors.schemes) do
        table.insert(entries, { theme.name, click = function()
          xdrvColors.setScheme(theme.name)
          config.config.xdrvColors = theme.name
          events.redraw()
          config.save()
        end, toggle = true, value = function() return xdrvColors.scheme.name == theme.name end })
      end
      -- a little ugly; adds the little break after the first theme
      table.insert(entries, 2, {})

      table.insert(entries, {})
      table.insert(entries, { 'Custom', click = function()
        xdrvColors.setScheme('custom')
        config.config.xdrvColors = 'custom'
        events.redraw()
        config.save()
      end, toggle = true, value = function() return xdrvColors.scheme.name == 'Custom' end })
      table.insert(entries, { 'Import from JSON...', click = function()
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
          events.redraw()
          config.save()
        end)
      end })

      return entries
    end},
    { 'Waveform (EXPERIMENTAL)', click = function()
      config.config.waveform = not config.config.waveform
      if config.config.waveform and conductor.fileData then
        waveform.init(conductor.fileData)
      else
        waveform.clear()
      end
      config.save()
    end, toggle = true, value = function() return config.config.waveform end },
    { 'Double-res waveform', click = function()
      config.config.doubleResWaveform = not config.config.doubleResWaveform
      if config.config.waveform and conductor.fileData then
        waveform.init(conductor.fileData)
      end
      config.save()
    end, toggle = true, value = function() return config.config.doubleResWaveform end },
    { 'Waveform opacity', set = function(value)
      config.config.waveformOpacity = value
    end, slider = true, value = function() return config.config.waveformOpacity end },
    { 'Waveform brightness', set = function(value)
      config.config.waveformBrightness = value
    end, slider = true, value = function() return config.config.waveformBrightness end },
    {},
    { 'Cat', click = function()
      if not catjam or catjam.delete then
        catjam = CatjamWidget(32, 32)
        openWidget(catjam)
      else
        catjam.delete = true
        catjam = nil
      end
    end, toggle = true, value = function() return not (not catjam or catjam.delete) end },
    { 'Disable native macOS menu', click = function()
      config.config.disableNativeMacOSBar = not config.config.disableNativeMacOSBar
      config.save()
      logs.warn('Restart required to take effect')
    end, toggle = true, value = function() return config.config.disableNativeMacOSBar end },
    },
  },
  { 'Help',
    {
      { 'View keybinds', click = function()
        edit.viewBinds = not edit.viewBinds
      end, bind = keybinds.binds.viewBinds },
      {},
      { 'About',         click = function() openWidget(AboutWidget(150, 150)) end },
      {},
      { 'Debug', {
        { '!! No support will be offered !!' },
        { 'Use the options here at your own risk' },
        toggle { 'Undo history',
          get = function() return config.config.debug.undoHistory end,
          set = function(v) config.config.debug.undoHistory = v end },
        toggle { 'Mods display',
          get = function() return config.config.debug.modsDisplay end,
          set = function(v) config.config.debug.modsDisplay = v end },
        toggle { 'Ignore draw cache',
          get = function() return config.config.debug.alwaysIgnoreCache end,
          set = function(v) config.config.debug.alwaysIgnoreCache = v end },
        { 'UI Test',       click = function() openWidget(UITestWidget(150, 150)) end },
      }}
    }
  }
}

function ActionBarWidget:new()
  ActionBarWidget.super.new(self, 0, 0)
  self.isMovable = false
  self.hasWindowDecorations = false
  self.resizable = false
  self.height = HEIGHT
  self.ignoreFocus = true

  self.items = self.barItems

  ---@type love.Text[]
  self.texts = {}
  for _, item in ipairs(self.items) do
    local text = love.graphics.newText(fonts.inter_12, item[1])
    table.insert(self.texts, text)
  end

  ---@type ContextWidget
  self.open = nil
  self.openIdx = nil
end

function ActionBarWidget:reloadAssets()
  ---@type love.Text[]
  self.texts = {}
  for _, item in ipairs(self.items) do
    local text = love.graphics.newText(fonts.inter_12, item[1])
    table.insert(self.texts, text)
  end
end

function ActionBarWidget:update()
  if self.open and self.open.delete then
    self.open = nil
    self.openIdx = nil
  end
end

---@param menuItem ActionBarItem
---@returns ContextWidgetEntry
function ActionBarWidget.actionBarToContext(menuItem)
  local entry = {}
  entry[1] = menuItem[1]
  entry[2] = menuItem.click
  if menuItem.set then
    entry[2] = menuItem.set
  end
  entry.bind = menuItem.bind
  local submenu = nil
  if menuItem[2] then
    submenu = menuItem[2]
  end
  if menuItem.getSubmenu then
    submenu = menuItem.getSubmenu()
  end
  if submenu then
    entry.hover = function(self, i)
      self:openChild(i, ContextWidget(0, 0, ActionBarWidget.actionBarsToContexts(submenu)))
    end
    entry.expandable = true
  end
  entry.toggle = menuItem.toggle
  entry.slider = menuItem.slider
  if menuItem.disabled then entry.disabled = menuItem.disabled() end
  if not (entry[2] or entry.expandable) then entry.disabled = true end
  if menuItem.value then entry.value = menuItem.value() end
  entry.formatValue = menuItem.formatValue

  return entry
end

---@param menuItems ActionBarItem[]
---@returns ContextWidgetEntry[]
function ActionBarWidget.actionBarsToContexts(menuItems)
  local newItems = {}
  for _, item in ipairs(menuItems) do
    table.insert(newItems, ActionBarWidget.actionBarToContext(item))
  end
  return newItems
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

      local subItems = self.items[i][2]
      local widget = ContextWidget(tx - GAP/2, self.y + self.height, self.actionBarsToContexts(subItems))
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