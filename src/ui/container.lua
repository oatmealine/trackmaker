local Node = require 'src.ui.node'
local Checkmark = require 'src.ui.checkmark'

---@class Container : Node
local Container = Node:extend()

function Container:new(children, x, y)
  Container.super.new(self, x, y)
  ---@type Node[]
  self.children = children
  local width, height = 0, 0
  for _, child in ipairs(self.children) do
    width = math.max(width, child.x + child.width)
    height = math.max(height, child.y + child.height)
  end
  self.width = width
  self.height = height
  self.rawX = 0
  self.rawY = 0
end

function Container:update()
  for _, child in ipairs(self.children) do
    child:update()
  end
end

function Container:click(x, y, button)
  for _, child in ipairs(self.children) do
    if child.active then
      child:loseFocus()
    end
    child.active = false
  end
  for _, child in ipairs(self.children) do
    if child:inBounds(x, y) and not child.disabled then
      child.active = true
      child:click(x - child.x, y - child.y, button)
      return
    end
  end
end
function Container:move(x, y)
  for _, child in ipairs(self.children) do
    child:move(x - child.x, y - child.y)
  end
end
function Container:textInput(t)
  for _, child in ipairs(self.children) do
    if child.active then
      child:textInput(t)
    end
  end
end
function Container:key(key, scancode, isRepeat)
  for _, child in ipairs(self.children) do
    if child.active then
      child:key(key, scancode, isRepeat)
    end
  end
end
function Container:eatsInputs()
  for _, child in ipairs(self.children) do
    if child.active then
      return child:eatsInputs()
    end
  end
  return false
end

function Container:loseFocus()
  for _, child in ipairs(self.children) do
    if child.active then
      child:loseFocus()
    end
    child.active = false
  end
end

function Container:draw()
  for _, child in ipairs(self.children) do
    child.rawX, child.rawY = self.rawX + child.x, self.rawY + child.y

    love.graphics.push()
    love.graphics.translate(round(child.x), round(child.y))

    child:draw()

    love.graphics.pop()
  end
end

---@param rows ({ [1]: Widget, [2]: Widget[] } | nil)[]
---@param width number?
function Container.placeFormLike(rows, width)
  local PAD = 10
  local GAP = 10
  local Y_GAP = 28

  local labelWidth = 0
  for _, row in ipairs(rows) do
    labelWidth = math.max(labelWidth, row[1].width)
  end

  local nodes = {}

  for i, row in ipairs(rows) do
    local y = PAD + (i - 1) * Y_GAP
    row[1].x = PAD + labelWidth/2 - row[1].width/2
    row[1].y = y + Y_GAP/2 - row[1].height/2
    table.insert(nodes, row[1])

    local remainderX = PAD + labelWidth
    local remainder = (width - PAD) - remainderX

    -- todo
    -- currently handled rather.. shobbily
    local x = GAP
    for i, child in ipairs(row[2]) do
      local width = remainder / #row[2] - GAP
      child.x = remainderX + x
      child.y = y + Y_GAP/2 - child.height/2
      if not child:is(Checkmark) then
        child.width = width
      else
        child.x = child.x + width/2 - child.width/2
      end
      x = x + width
      table.insert(nodes, child)
    end
  end

  return nodes
end

---@param rows Node[][]
---@param width number?
---@param center boolean?
function Container.placeRows(rows, width, center)
  local PAD = 10
  local GAP = 10
  local Y_GAP = 28

  local nodes = {}
  local y = PAD
  for _, row in ipairs(rows) do
    local x = PAD
    if center then
      x = x + width/2
      for _, elem in ipairs(row) do
        x = x - elem.width/2 - GAP/2
      end
      x = x - GAP/2
    end
    for i, elem in ipairs(row) do
      elem.x = x
      elem.y = y + Y_GAP/2 - elem.height/2
      table.insert(nodes, elem)

      x = x + elem.width + GAP
      if width and x > (width - PAD) and i ~= 1 then
        x = PAD
        y = y + Y_GAP
      end
    end
    y = y + Y_GAP
  end

  return nodes
end

return Container