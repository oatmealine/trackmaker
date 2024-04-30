local Node = require 'src.ui.node'

---@class Container : Node
local Container = Node:extend()

function Container:new(children)
  ---@type Node[]
  self.children = children
end

function Container:update()
  for _, child in ipairs(self.children) do
    child:update()
  end
end

function Container:click(x, y, button)
  for _, child in ipairs(self.children) do
    if child:inBounds(x, y) then
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

function Container:draw()
  for _, child in ipairs(self.children) do
    love.graphics.push()
    love.graphics.translate(round(child.x), round(child.y))

    child:draw()

    love.graphics.pop()
  end
end

---@param rows Widget[][]
---@param width number?
function Container.placeRows(rows, width)
  local PAD = 10
  local GAP = 10
  local Y_GAP = 28

  local nodes = {}
  local y = PAD
  for _, row in ipairs(rows) do
    local x = PAD
    for _, elem in ipairs(row) do
      elem.x = x
      elem.y = y + Y_GAP/2 - elem.height/2
      table.insert(nodes, elem)

      x = x + elem.width + GAP
      if width and x > (width - PAD) then
        x = PAD
        y = y + Y_GAP
      end
    end
    y = y + Y_GAP
  end

  return nodes
end

return Container