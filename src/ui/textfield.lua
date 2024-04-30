local Node = require 'src.ui.node'

local utf8 = require 'utf8'

---@class Textfield : Node
local Textfield = Node:extend()

local PAD_H = 6
local PAD_V = 4

function Textfield:new(x, y, width, default, trigger)
  self.x = x
  self.y = y
  self.value = default or ''

  self.textObj = love.graphics.newText(fonts.inter_12, self.value)

  self.width = PAD_H * 2 + width
  self.height = PAD_V * 2 + fonts.inter_12:getHeight()

  self.cursor = utf8.len(self.value)

  self.trigger = trigger
end

function Textfield:updateValue()
  self.textObj = love.graphics.newText(fonts.inter_12, self.value)
end

function Textfield:textInput(t)
  if self.cursor == 0 then
    self.value = t .. self.value
  else
    self.value = utf8sub(self.value, 1, self.cursor) .. t .. utf8sub(self.value, self.cursor + 1)
  end
  self.cursor = self.cursor + 1
  self:updateValue()
end

function Textfield:click()
  self.cursor = utf8.len(self.value)
end

function Textfield:eatsInputs()
  return self.active
end

---@param key love.KeyConstant
function Textfield:key(key, scancode, isRepeat)
  if key == 'backspace' and self.cursor > 0 then
    self.value = utf8sub(self.value, 1, self.cursor - 1) .. utf8sub(self.value, self.cursor + 1)

    self.cursor = self.cursor - 1

    self:updateValue()

    return true
  elseif key == 'return' then
    if self.trigger then self.trigger(self.value) end
    return true
  elseif key == 'left' then
    self.cursor = math.max(self.cursor - 1, 0)
    return true
  elseif key == 'right' then
    self.cursor = math.min(self.cursor + 1, utf8.len(self.value))
    return true
  elseif key == 'home' then
    self.cursor = 0
    return true
  elseif key == 'end' then
    self.cursor = utf8.len(self.value)
    return true
  end
end

function Textfield:draw()
  love.graphics.setColor(0.15, 0.15, 0.15, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(0.3, 0.3, 0.3, 1)
  love.graphics.rectangle('line', 0, 0, self.width, self.height, 1, 1)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.textObj, PAD_H, self.height/2 - self.textObj:getHeight()/2)

  if self.active then
    local cursorPos = self.cursor > 0 and fonts.inter_12:getWidth(utf8sub(self.value, 1, self.cursor)) or 0

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print('|', round(PAD_H + cursorPos), round(self.height/2 - fonts.inter_12:getHeight()/2))
  end
end

return Textfield