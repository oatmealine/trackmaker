local Node = require 'src.ui.node'
local ContextWidget = require 'src.widgets.context'

---@class Select : Node
local Select = Node:extend()

local PAD_H = 6
local PAD_V = 4
local PAD_RIGHT = 20

function Select:new(x, y, options, trigger, default)
  self.x = x
  self.y = y
  self.selectedIdx = default or 1
  self.options = options
  self.trigger = trigger

  self.textObjs = {}
  local width = 0
  for i, option in ipairs(self.options) do
    local text = love.graphics.newText(fonts.inter_12, option)
    self.textObjs[i] = text
    width = math.max(width, text:getWidth())
  end

  self.width = PAD_H * 2 + width + PAD_RIGHT
  self.height = PAD_V * 2 + fonts.inter_12:getHeight()
end

function Select:click(x, y, button)
  if button == 1 then
    local options = {}
    for i, option in ipairs(self.options) do
      table.insert(options, { option, function()
        self.selectedIdx = i
        if self.trigger then
          self.trigger(i)
        end
      end })
    end

    -- dumb hack but oh well
    local widgets = getWidgets()
    local w = widgets[#widgets]

    local ctx = ContextWidget(w.x + self.x, w.y + self.y + 24 + 2 + self.height, options)
    openWidget(ctx)
  end
end

function Select:draw()
  if self.hovered then
    if love.mouse.isDown(1) then
      love.graphics.setColor(0.1, 0.1, 0.1, 1)
    else
      love.graphics.setColor(0.3, 0.3, 0.3, 1)
    end
  else
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
  end
  love.graphics.rectangle('fill', 0, 0, self.width, self.height, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.3, 0.3, 0.3, 1)
  love.graphics.rectangle('line', 0, 0, self.width, self.height, 1, 1)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.textObjs[self.selectedIdx], PAD_H, self.height/2 - fonts.inter_12:getHeight()/2)
  love.graphics.printf('▼', PAD_H, self.height/2 - fonts.inter_12:getHeight()/2, self.width - PAD_H * 2, 'right')
end

return Select