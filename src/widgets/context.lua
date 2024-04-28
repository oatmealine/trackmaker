---@class ContextWidget : Widget
local ContextWidget = Widget:extend()

local MIN_WIDTH = 80
local HEIGHT = 20
local MARGIN = 2

---@param entries { [1]: string, [2]: fun() }[]
function ContextWidget:new(x, y, entries)
  ContextWidget.super.new(self, x, y)
  self.resizable = false
  self.hasWindowDecorations = false
  self.isMovable = false

  ---@type love.Text[]
  self.texts = {}
  local width = MIN_WIDTH
  for _, entry in ipairs(entries) do
    local text = love.graphics.newText(fonts.inter_12, entry[1])
    table.insert(self.texts, text)
    width = math.max(width, text:getWidth())
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
    love.graphics.draw(text, MARGIN, round(y + HEIGHT/2 - fonts.inter_12:getHeight()/2))
  end
end

return ContextWidget