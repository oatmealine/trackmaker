local edit   = require 'src.edit'
local logs   = require 'src.logs'
local config = require 'src.config'

local ContextWidget = require 'src.widgets.context'
local MetadataWidget = require 'src.widgets.metadata'
local AboutWidget = require 'src.widgets.about'
local CatjamWidget = require 'src.widgets.catjam'
local UITestWidget = require 'src.widgets.uitest'

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
      { 'Save',        function() chart.quickSave()  end, bind = keybinds.binds.quicksave },
      { 'Save as...',  function() chart.saveChart()  end, bind = keybinds.binds.save },
      { 'Import',   hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { '.SM/.SSC file', function() chart.importMenu('sm,ssc') end },
        }))
      end, expandable = true },
      { 'Metadata...', function() openWidget(MetadataWidget(100, 100)) end },
      { 'Exit',        function() love.event.quit(0) end}
    }
  end},
  { 'Edit', function()
    return {
      { 'Undo',  function() edit.undo()  end, bind = keybinds.binds.undo },
      { 'Redo',  function() edit.redo()  end, bind = keybinds.binds.redo },

      { 'Cut',   function() edit.cut()   end, bind = keybinds.binds.cut },
      { 'Copy',  function() edit.copy()  end, bind = keybinds.binds.copy },
      { 'Paste', function() edit.paste() end, bind = keybinds.binds.paste },

      { 'Mirror',   hover = function(self, i)
        self:openChild(i, ContextWidget(0, 0, {
          { 'Horizontally', function() edit.mirrorSelection(edit.MirrorType.Horizontal) end },
          { 'Vertically',   function() edit.mirrorSelection(edit.MirrorType.Vertical)   end },
          { 'Both',         function() edit.mirrorSelection(edit.MirrorType.Both)       end },
        }))
      end, expandable = true },

      { 'Select All', function() edit.selectAll() end, bind = keybinds.binds.selectAll },
      { 'Delete',     function() edit.deleteKey() end, bind = keybinds.binds.delete },
    }
  end},
  { 'Options', function()
    local width, height, flags = love.window.getMode()
    return {
      { 'Beat tick', function()
        config.config.beatTick = not config.config.beatTick
        logs.log('Beat tick: ' .. (config.config.beatTick and 'ON' or 'OFF'))
      end, toggle = true, value = config.config.beatTick, bind = keybinds.binds.beatTick },
      { 'Note tick', function()
        config.config.noteTick = not config.config.noteTick
        logs.log('Note tick: ' .. (config.config.noteTick and 'ON' or 'OFF'))
      end, toggle = true, value = config.config.noteTick, bind = keybinds.binds.noteTick },
      { 'VSync', function()
        flags.vsync = 1 - flags.vsync
        logs.log('VSync: ' .. ((flags.vsync == 1) and 'ON' or 'OFF'))
        ---@diagnostic disable-next-line: param-type-mismatch
        love.window.setMode(width, height, flags)
      end, toggle = true, value = flags.vsync == 1 },
      { 'Disable multithreading', function()
        config.config.noMultithreading = not config.config.noMultithreading
        logs.log('Multithreading: ' .. (config.config.noMultithreading and 'OFF' or 'ON'))
        if config.config.noMultithreading then
          logs.log('Only touch this if you know what you\'re doing!')
        end
      end, toggle = true, value = config.config.noMultithreading },
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
      { 'UI Test',         function() openWidget(UITestWidget(150, 150)) end },
      { 'About',         function() openWidget(AboutWidget(150, 150)) end },
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
  self.width = sw
  self.height = HEIGHT

  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  local x = MARGIN
  love.graphics.setColor(1, 1, 1, 1)
  for i, item in ipairs(self.texts) do
    local open = self.openIdx == i

    if open then
      love.graphics.setColor(0.2, 0.2, 0.2, 1)
      love.graphics.rectangle('fill', x - GAP/2, 0, item:getWidth() + GAP, HEIGHT)
    end
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.draw(item, round(x), round(HEIGHT/2 - item:getHeight()/2))
    x = x + item:getWidth() + GAP
  end
end

return ActionBarWidget