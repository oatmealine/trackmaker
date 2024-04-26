
--[[
 * Converts an HSL color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes h, s, and l are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 1].
]]
local function hslToRgb(h, s, l)
  local r, g, b

  if s == 0 then
    r, g, b = l, l, l -- achromatic
  else
    function hue2rgb(p, q, t)
      if t < 0   then t = t + 1 end
      if t > 1   then t = t - 1 end
      if t < 1/6 then return p + (q - p) * 6 * t end
      if t < 1/2 then return q end
      if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
      return p
    end

    local q
    if l < 0.5 then q = l * (1 + s) else q = l + s - l * s end
    local p = 2 * l - q

    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  end

  return r, g, b
end

--[[
 * Converts an HSL color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes h, s, and l are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 1].
]]
local function rgbToHsl(r, g, b)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, l

  l = (max + min) / 2
  if max == 0 then s = 0 else s = (max - min) / max end

  if max == min then
    h, s = 0, 0 -- achromatic
  else
    local d = max - min
    local s
    if l > 0.5 then s = d / (2 - max - min) else s = d / (max + min) end
    if max == r then
      h = (g - b) / d
      if g < b then h = h + 6 end
    elseif max == g then h = (b - r) / d + 2
    elseif max == b then h = (r - g) / d + 4
    end
    h = h / 6
  end

  return h, s, l
end


--[[
 * Converts an RGB color value to HSV. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes r, g, and b are contained in the set [0, 1] and
 * returns h, s, and v in the set [0, 1].
]]
local function rgbToHsv(r, g, b)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, v
  v = max

  local d = max - min
  if max == 0 then s = 0 else s = d / max end

  if max == min then
    h = 0 -- achromatic
  else
    if max == r then
    h = (g - b) / d
    if g < b then h = h + 6 end
    elseif max == g then h = (b - r) / d + 2
    elseif max == b then h = (r - g) / d + 4
    end
    h = h / 6
  end

  return h, s, v
end

--[[
 * Converts an HSV color value to RGB. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSV_color_space.
 * Assumes h, s, and v are contained in the set [0, 1] and
 * returns r, g, and b in the set [0, 1].
]]
local function hsvToRgb(h, s, v)
  local r, g, b

  local i = math.floor(h * 6);
  local f = h * 6 - i;
  local p = v * (1 - s);
  local q = v * (1 - f * s);
  local t = v * (1 - (1 - f) * s);

  i = i % 6

  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  elseif i == 5 then r, g, b = v, p, q
  end

  return r, g, b
end

---@class color
---@field r number @red, 0.0 - 1.0
---@field g number @green, 0.0 - 1.0
---@field b number @blue, 0.0 - 1.0
---@field a number @alpha, 0.0 - 1.0
local col = {}

--- for use in actor:diffuse(col:unpack())
---@return number, number, number, number
function col:unpack()
  return self.r, self.g, self.b, self.a
end

-- conversions

---@return number, number, number
function col:rgb()
  return self.r, self.g, self.b
end

---@return number, number, number
function col:hsl()
  return rgbToHsl(self.r, self.g, self.b)
end

---@return number, number, number
function col:hsv()
  return rgbToHsv(self.r, self.g, self.b)
end

---@return string
function col:hex()
  return string.format('%02x%02x%02x',
    math.floor(self.r * 255),
    math.floor(self.g * 255),
    math.floor(self.b * 255))
end

-- setters

---@return color
function col:hue(h)
  local _, s, v = self:hsv()
  return hsv(h % 1, s, v, self.a)
end

---@return color
function col:huesmooth(h)
  local _, s, v = self:hsv()
  return shsv(h % 1, s, v, self.a)
end

---@return color
function col:alpha(a)
  return rgb(self.r, self.g, self.b, self.a * a)
end

--- multiplies current alpha by provided value
---@return color
function col:malpha(a)
  return rgb(self.r, self.g, self.b, self.a * a)
end

-- effects

---@return color
function col:invert()
  return rgb(1 - self.r, 1 - self.g, 1 - self.b, self.a)
end

---@return color
function col:grayscale()
  return rgb(self.r * 0.299 + self.g * 0.587 + self.b * 0.114, self.a)
end

---@return color
function col:hueshift(a)
  local h, s, v = self:hsv()
  return hsv((h + a) % 1, s, v, self.a)
end

local colmeta = {}

function colmeta:__index(i)
  if i == 1 then return self.r end
  if i == 2 then return self.g end
  if i == 3 then return self.b end
  if i == 4 then return self.a end
  return col[i]
end

local function typ(a)
  return (type(a) == 'table' and a.r and a.g and a.b and a.a) and 'color' or type(a)
end

local function genericop(a, b, f, name)
  local typea = typ(a)
  local typeb = typ(b)
  if typea == 'number' then
    return rgb(f(b.r, a), f(b.g, a), f(b.b, a), b.a)
  elseif typeb == 'number' then
    return rgb(f(a.r, b), f(a.g, b), f(a.b, b), a.a)
  elseif typea == 'color' and typeb == 'color' then
    return rgb(f(a.r, b.r), f(a.g, b.g), f(a.b, b.b), f(a.a, b.a))
  end
  error('cant apply ' .. name .. ' to ' .. typea .. ' and ' .. typeb, 3)
end

function colmeta.__add(a, b)
  return genericop(a, b, function(a, b) return a + b end, 'add')
end
function colmeta.__sub(a, b)
  return genericop(a, b, function(a, b) return a - b end, 'sub')
end
function colmeta.__mul(a, b)
  return genericop(a, b, function(a, b) return a * b end, 'mul')
end
function colmeta.__div(a, b)
  return genericop(a, b, function(a, b) return a / b end, 'div')
end

function colmeta.__eq(a, b)
  return (typ(a) == 'color' and typ(b) == 'color') and (a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a)
end

function colmeta:__tostring()
  return '#' .. self:hex()
end
colmeta.__name = 'color'

-- constructors

---@return color
function rgb(r, g, b, a)
  a = a or 1
  return setmetatable({r = r, g = g, b = b, a = a}, colmeta)
end

---@return color
function hsl(h, s, l, a)
  a = a or 1
  local r, g, b = hslToRgb(h, s, l)
  return setmetatable({r = r, g = g, b = b, a = a}, colmeta)
end

---@return color
function hsv(h, s, v, a)
  a = a or 1
  local r, g, b = hsvToRgb(h, s, v)
  return setmetatable({r = r, g = g, b = b, a = a}, colmeta)
end

--- smoother hsv. not correct but looks nicer
---@return color
function shsv(h, s, v, a)
  return hsv(h * h * (3 - 2 * h), s, v, a)
end

---@param hex string
---@return color
function hex(hex)
  hex = string.gsub(hex, '#', '')
  if string.len(hex) == 3 then
    return rgb((tonumber('0x' .. string.sub(hex, 1, 1)) * 17) / 255, (tonumber('0x' .. string.sub(hex, 2, 2)) * 17) / 255, (tonumber('0x' .. string.sub(hex, 3, 3)) * 17) / 255)
  else
    return rgb(tonumber('0x' .. string.sub(hex, 1, 2)) / 255, tonumber('0x' .. string.sub(hex, 3, 4)) / 255, tonumber('0x' .. string.sub(hex, 5, 6)) / 255)
  end
end