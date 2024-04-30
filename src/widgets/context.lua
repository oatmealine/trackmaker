---@class ContextWidget : Widget
local ContextWidget = Widget:extend()

local MIN_WIDTH = 100
local HEIGHT = 24
local MARGIN = 7
local GAP = 10

local LEFT_PAD = 14
local RIGHT_PAD = 14

---@alias ContextWidgetEntry { [1]: string, [2]: fun(self: ContextWidget)?, bind: Keybind?, hover: fun(self: ContextWidget, i: number)?, toggle: boolean?, value: any, expandable: boolean? }

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
    local text = love.graphics.newText(fonts.inter_12, entry[1])
    local w = text:getWidth()
    table.insert(self.texts, text)
    if entry.bind then
      local bindText = love.graphics.newText(fonts.inter_12, keybinds.formatBind(entry.bind))
      self.bindTexts[i] = bindText
      w = w + bindText:getWidth() + GAP
    end
    width = math.max(width, w)
  end

  self.width = MARGIN * 2 + LEFT_PAD + RIGHT_PAD + width
  self.height = HEIGHT * #entries

  self.entries = entries

  self.supressClose = false
  self.hoveredIdx = 0
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
  self.child = child
  child.parent = self
  child.x = self.x + self.width
  child.y = self.y + (i - 1) * HEIGHT
  openWidget(child)
  return true
end

function ContextWidget:move(x, y)
  local i = math.floor(y / HEIGHT) + 1
  local entry = self.entries[i]
  if i ~= self.hoveredIdx then
    self.hoveredIdx = i
    if self.child then
      self.child.delete = true
      self.child = nil
    end

    if entry and entry.hover then
      entry.hover(self, i)
    end
  end
end

function ContextWidget:click(x, y)
  local i = math.floor(y / HEIGHT) + 1
  local entry = self.entries[i]
  if entry and entry[2] then
    local res = entry[2](self)
    if not res then
      self:close()
    end
  end
end

function ContextWidget:drawInner()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
  for i, text in ipairs(self.texts) do
    local entry = self.entries[i]

    local y = (i - 1) * HEIGHT
    local botY = i * HEIGHT

    local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
    if my > y and my <= botY and mx > 0 and mx < self.width then
      love.graphics.setColor(0.2, 0.2, 0.2, 1)
      love.graphics.rectangle('fill', 0, y, self.width, botY - y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(text, MARGIN + LEFT_PAD, round(y + HEIGHT/2 - text:getHeight()/2))

    local bindText = self.bindTexts[i]
    if bindText then
      love.graphics.setColor(0.8, 0.8, 0.8, 1)
      love.graphics.draw(bindText, self.width - MARGIN - RIGHT_PAD - bindText:getWidth(), round(y + HEIGHT/2 - bindText:getHeight()/2))
    end

    if entry.toggle and entry.value then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print('✓', MARGIN, y + HEIGHT/2 - fonts.inter_12:getHeight()/2)
    end
    if entry.expandable then
      love.graphics.printf('►', MARGIN, y + HEIGHT/2 - fonts.inter_12:getHeight()/2, self.width - MARGIN*2, 'right')
    end
  end
end

return ContextWidget