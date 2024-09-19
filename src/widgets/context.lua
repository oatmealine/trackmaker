local colors = require 'src.colors'

---@class ContextWidget : Widget
local ContextWidget = Widget:extend()

local MIN_WIDTH = 100
local HEIGHT = 22
local MARGIN = 7
local GAP = 10

local LEFT_PAD = 14
local RIGHT_PAD = 14

---@alias ContextWidgetEntry { [1]: string, [2]: fun(self: ContextWidget)?, bind: Keybind?, hover: fun(self: ContextWidget, i: number)?, toggle: boolean?, value: any, expandable: boolean?, slider: boolean?, disabled: boolean? }

---@param entries ContextWidgetEntry[]
function ContextWidget:new(x, y, entries)
  ContextWidget.super.new(self, x, y)
  self.resizable = false
  self.hasWindowDecorations = false
  self.isMovable = false

  self.name = 'ContextWidget'

  self.child = nil
  self.parent = nil

  ---@type love.Text[]
  self.texts = {}
  ---@type love.Text[]
  self.bindTexts = {}
  local width = MIN_WIDTH
  for i, entry in ipairs(entries) do
    if entry[1] then
      local text = love.graphics.newText(fonts.inter_12, entry[1])
      local w = text:getWidth()
      self.texts[i] =  text
      if entry.bind then
        local bindText = love.graphics.newText(fonts.inter_12, keybinds.formatBind(entry.bind))
        self.bindTexts[i] = bindText
        w = w + bindText:getWidth() + GAP
      end
      width = math.max(width, w)
    end
  end

  self.entries = entries

  self.width = MARGIN * 2 + LEFT_PAD + RIGHT_PAD + width
  self.height = self:getElemY(#self.entries + 1)

  if self.x + self.width >= love.graphics.getWidth() then
    self.x = love.graphics.getWidth() - self.width
  end

  self.supressClose = false
  self.hoveredIdx = 0
  self.activeIdx = nil
end

function ContextWidget:getElemHeight(i)
  local entry = self.entries[i]
  if entry[1] then
    return HEIGHT
  else
    -- gap
    return 8
  end
end
function ContextWidget:getElemY(elem)
  local y = 0
  for i = 1, elem - 1 do
    y = y + self:getElemHeight(i)
  end
  return y
end

function ContextWidget:close()
  local ctx = self
  while ctx do
    ctx.delete = true
    ctx = ctx.parent
  end
end

function ContextWidget:loseFocus(to)
  if to ~= self.child and to ~= self.parent and to ~= self then
    self:close()
  end
end

---@param child ContextWidget
function ContextWidget:openChild(i, child)
  self.activeIdx = i
  self.child = child
  child.parent = self
  child.x = self.x + self.width
  child.y = self.y + self:getElemY(i)
  openWidget(child)
  return true
end

function ContextWidget:getElemFromY(y)
  local elemY = 0
  for i, entry in ipairs(self.entries) do
    elemY = elemY + self:getElemHeight(i)
    if y < elemY then
      return i, entry
    end
  end
end

function ContextWidget:move(x, y)
  local i, entry = self:getElemFromY(y)

  if not entry then return end

  if i ~= self.hoveredIdx then
    self.hoveredIdx = i
    if self.child then
      self.child.delete = true
      self.child = nil
      if i ~= self.activeIdx then
        self.activeIdx = nil
      end
    end

    if entry and entry.hover then
      entry.hover(self, i)
    end
  end
  if entry.slider and love.mouse.isDown(1) then
    entry.value = x / self.width
    entry[2](entry.value)
  end
end

function ContextWidget:click(x, y, button)
  if button ~= 1 then return end

  local _, entry = self:getElemFromY(y)

  if not entry then return end

  if entry[2] and not entry.disabled and not entry.slider then
    local res = entry[2](self)
    if not res then
      self:close()
    end
  end
end

function ContextWidget:draw()
  love.graphics.setColor(colors.element:unpack())
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  local y = 0
  for i, entry in ipairs(self.entries) do
    local botY = y + self:getElemHeight(i)

    local hovered = false

    if entry[1] and not entry.disabled then
      local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
      hovered = self.activeIdx == i or my > y and my <= botY and mx > 0 and mx < self.width
      if hovered then
        love.graphics.setColor(colors.hover:unpack())
        love.graphics.rectangle('fill', 0, y, self.width, botY - y)
      end
    end

    if entry.slider and entry.value then
      if hovered then
        love.graphics.setColor(colors.active:unpack())
      else
        love.graphics.setColor(colors.hover:unpack())
      end
      love.graphics.rectangle('fill', 0, y, self.width * entry.value, botY - y)

      love.graphics.setColor(colors.textSecondary:unpack())
      love.graphics.printf(string.format('%.2f', entry.value), MARGIN, y + HEIGHT/2 - fonts.inter_12:getHeight()/2, self.width - MARGIN*2, 'right')
      love.graphics.setColor(colors.text:unpack())
      if hovered then
        love.graphics.setColor((colors.hoverText or colors.text):unpack())
      end
      love.graphics.arc('fill', MARGIN + LEFT_PAD/2, y + HEIGHT/2, LEFT_PAD * 0.35, -math.pi * 0.5, (-math.pi * 0.5) + entry.value * math.pi * 2)

      if (not hovered) and colors.hoverText then
        local x1, y1 = love.graphics.transformPoint(0, y)
        local x2, y2 = love.graphics.transformPoint(self.width * entry.value, botY)
        love.graphics.setScissor(x1, y1, x2 - x1, y2 - y1)
        love.graphics.setColor(colors.hoverText:unpack())
        love.graphics.arc('fill', MARGIN + LEFT_PAD/2, y + HEIGHT/2, LEFT_PAD * 0.35, -math.pi * 0.5, (-math.pi * 0.5) + entry.value * math.pi * 2)
        love.graphics.setScissor()
      end
    end

    local text = self.texts[i]
    if text then
      if (not hovered) and entry.slider and entry.value and colors.hoverText then
        local x1, y1 = love.graphics.transformPoint(0, y)
        local x2, y2 = love.graphics.transformPoint(self.width * entry.value, botY)
        local x3, _  = love.graphics.transformPoint(self.width, botY)
        love.graphics.setScissor(x1, y1, x2 - x1, y2 - y1)
        love.graphics.setColor(colors.hoverText:unpack())
        love.graphics.draw(text, MARGIN + LEFT_PAD, round(y + HEIGHT/2 - text:getHeight()/2))
        love.graphics.setScissor(x2, y1, x3 - x2, y2 - y1)
        love.graphics.setColor(colors.text:unpack())
        love.graphics.draw(text, MARGIN + LEFT_PAD, round(y + HEIGHT/2 - text:getHeight()/2))
        love.graphics.setScissor()
      else
        love.graphics.setColor(colors.text:unpack())
        if hovered then
          love.graphics.setColor((colors.hoverText or colors.text):unpack())
        end
        if entry.disabled then
          love.graphics.setColor(colors.textSecondary:unpack())
        end
        love.graphics.draw(text, MARGIN + LEFT_PAD, round(y + HEIGHT/2 - text:getHeight()/2))
      end
    else
      love.graphics.setColor((colors.dull or colors.hover):unpack())
      love.graphics.line(0, (y + botY)/2, self.width, (y + botY)/2)
    end

    local bindText = self.bindTexts[i]
    if bindText then
      love.graphics.setColor(colors.textSecondary:unpack())
      love.graphics.draw(bindText, self.width - MARGIN - RIGHT_PAD - bindText:getWidth(), round(y + HEIGHT/2 - bindText:getHeight()/2))
    end

    if entry.toggle and entry.value then
      love.graphics.setColor(colors.text:unpack())
      if hovered then
        love.graphics.setColor((colors.hoverText or colors.text):unpack())
      end
      love.graphics.print('✓', MARGIN, y + HEIGHT/2 - fonts.inter_12:getHeight()/2)
    end
    if entry.expandable then
      love.graphics.setColor(colors.text:unpack())
      if hovered then
        love.graphics.setColor((colors.hoverText or colors.text):unpack())
      end
      love.graphics.printf('►', MARGIN, y + HEIGHT/2 - fonts.inter_12:getHeight()/2, self.width - MARGIN*2, 'right')
    end

    y = botY
  end
end

return ContextWidget