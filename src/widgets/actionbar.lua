local chart = require 'src.chart'
local edit  = require 'src.edit'
local logs  = require 'src.logs'

local ContextWidget = require 'src.widgets.context'
local MetadataWidget = require 'src.widgets.metadata'
local AboutWidget = require 'src.widgets.about'

---@class ActionBarWidget : Widget
local ActionBarWidget = Widget:extend()

local HEIGHT = 24
local GAP = 14
local MARGIN = GAP / 2

local items = {
  { 'File', function()
    return {
      { 'Open',        function() chart.openChart()  end, bind = keybinds.binds.open },
      { 'Save',        function() chart.quickSave()  end, bind = keybinds.binds.quicksave },
      { 'Save as...',  function() chart.saveChart()  end, bind = keybinds.binds.save },
      { 'Metadata...', function() openWidget(MetadataWidget(100, 100)) end },
      { 'Exit',        function() love.event.quit(0) end}
    }
  end},
  { 'Edit', function()
    return {
      { 'Cut',   function() edit.cut()   end, bind = keybinds.binds.cut },
      { 'Copy',  function() edit.copy()  end, bind = keybinds.binds.copy },
      { 'Paste', function() edit.paste() end, bind = keybinds.binds.paste },
    }
  end},
  { 'Help', function()
    local width, height, flags = love.window.getMode()
    return {
      { 'View keybinds', function() edit.viewBinds = not edit.viewBinds end, bind = keybinds.binds.viewBinds },
      { 'VSync: ' .. ((flags.vsync == 1) and 'ON' or 'OFF'), function()
        flags.vsync = 1 - flags.vsync
        logs.log('VSync: ' .. ((flags.vsync == 1) and 'ON' or 'OFF'))
        ---@diagnostic disable-next-line: param-type-mismatch
        love.window.setMode(width, height, flags)
      end },
      { 'About',         function() openWidget(AboutWidget(150, 150)) end }
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
function ActionBarWidget:click(x, y)
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