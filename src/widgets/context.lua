---@class ContextWidget : Widget
local ContextWidget = Widget:extend()

local MIN_WIDTH = 100
local HEIGHT = 24
local MARGIN = 7
local GAP = 10

---@param entries { [1]: string, [2]: fun(), bind: Keybind? }[]
function ContextWidget:new(x, y, entries)
  ContextWidget.super.new(self, x, y)
  self.resizable = false
  self.hasWindowDecorations = false
  self.isMovable = false

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

  self.width = MARGIN * 2 + width
  self.height = HEIGHT * #entries

  self.entries = entries
end

function ContextWidget:loseFocus()
  self.delete = true
end

function ContextWidget:click(x, y)
  local i = math.floor(y / HEIGHT) + 1
  local entry = self.entries[i]
  if entry then
    entry[2]()
  end
  self.delete = true
end

function ContextWidget:drawInner()
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
  for i, text in ipairs(self.texts) do
    local y = (i - 1) * HEIGHT
    local botY = i * HEIGHT

    local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
    if my > y and my <= botY and mx > 0 and mx < self.width then
      love.graphics.setColor(0.2, 0.2, 0.2, 1)
      love.graphics.rectangle('fill', 0, y, self.width, botY - y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(text, MARGIN, round(y + HEIGHT/2 - text:getHeight()/2))

    local bindText = self.bindTexts[i]
    if bindText then
      love.graphics.setColor(0.8, 0.8, 0.8, 1)
      love.graphics.draw(bindText, self.width - MARGIN - bindText:getWidth(), round(y + HEIGHT/2 - bindText:getHeight()/2))
    end
  end
end

return ContextWidget