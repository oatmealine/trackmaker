---@class easable
---@field eased number | any
---@field target number | any
---@field speed number
local easable = {}

--- move towards a new target
function easable:set(n)
  self.target = n
end

--- move towards a new target additively
function easable:add(n)
  self.target = self.target + n
end

--- set both the eased value and the target
function easable:reset(n)
  self.target = n
  self.eased = n
end

---@param dt number
function easable:update(dt)
  self.eased = math.pow(self.speed, -dt) * (self.eased - self.target) + self.target
end

function easable:__tostring()
  return 'easable (' .. self.eased .. ' towards ' .. self.target .. ')'
end

easable.__index = easable
easable.__name = 'easable'

---@return easable
return function(default, speed)
  return setmetatable({
    eased = default,
    target = default,
    speed = speed and math.pow(2, speed) or 2
  }, easable)
end