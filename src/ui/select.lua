local Node = require 'src.ui.node'
local ContextWidget = require 'src.widgets.context'
local colors = require 'src.colors'

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
  if self.disabled then return end

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

    local ctx = ContextWidget(self.rawX, self.rawY + self.height, options)
    ctx.width = self.width
    openWidget(ctx)
  end
end

function Select:draw()
  if self.hovered and not self.disabled then
    if love.mouse.isDown(1) then
      love.graphics.setColor(colors.down:unpack())
    else
      love.graphics.setColor(colors.hover:unpack())
    end
  else
    love.graphics.setColor(colors.element:unpack())
  end
  love.graphics.rectangle('fill', 0, 0, self.width, self.height, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(colors.border:unpack())
  love.graphics.rectangle('line', 0, 0, self.width, self.height, 1, 1)

  if self.disabled then
    love.graphics.setColor(colors.textSecondary:unpack())
  else
    love.graphics.setColor(colors.text:unpack())
  end
  love.graphics.draw(self.textObjs[self.selectedIdx], PAD_H, self.height/2 - fonts.inter_12:getHeight()/2)
  love.graphics.printf('▼', PAD_H, self.height/2 - fonts.inter_12:getHeight()/2, self.width - PAD_H * 2, 'right')
end

return Select