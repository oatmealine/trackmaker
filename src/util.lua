local utf8 = require 'utf8'

---@generic T
---@param a T
---@param b T
---@param x number
---@return T
function mix(a, b, x)
  return a + (b - a) * x
end

function utf8sub(s, a, b)
  a = a or 0
  b = b or utf8.len(s)
  if b < a then return '' end
  return string.sub(s, (utf8.offset(s, a) or 1), (utf8.offset(s, b + 1) or (string.len(s) + 1)) - 1)
end

---@generic T table<any>
---@param tab T
---@return T
function copy(tab)
  return {unpack(tab)}
end

---@generic T table<any>
---@param tab T
---@return T
function deepcopy(tab)
  local new = {}
  for k, v in pairs(tab) do
    if type(v) == 'table' then
      local mt = getmetatable(v)
      new[k] = deepcopy(v)
      if mt then
        setmetatable(new[k], deepcopy(mt))
      end
    else
      new[k] = v
    end
  end
  return new
end

function countKeys(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end


---@generic T
---@param t table<T, any>
---@return T[]
function getKeys(t)
  local keys = {}
  for key in pairs(t) do
    table.insert(keys, key)
  end
  return keys
end

function round(n)
  return n >= 0 and math.floor(n + 0.5) or math.ceil(n - 0.5)
end

---@param x number
---@param a number
---@param b number
---@return number
function clamp(x, a, b)
  return math.max(math.min(x, math.max(a, b)), math.min(a, b))
end

QUANTS = {
  1,
  1 / 2,
  1 / 3,
  1 / 4,
  1 / 5,
  1 / 6,
  1 / 8,
  1 / 12,
  1 / 16,
  1 / 24,
  1 / 48,
}

EPSILON = QUANTS[#QUANTS] / 8 -- div by 8 to be safe

function beatCmp(a, b)
  return a and b and math.abs(a - b) < EPSILON
end

function getQuantIndex(beat)
  for i, quant in ipairs(QUANTS) do
    if math.abs(beat - round(beat / quant) * quant) < 0.01 then
      return i
    end
  end
  return #QUANTS
end

function getDivision(quantIdx)
  return 4 / QUANTS[quantIdx]
end

function quantize(beat, quantI)
  local quant = QUANTS[quantI]
  return round(beat / quant) * quant
end

local function suffixSnap(n)
  if n % 10 == 1 and n ~= 11 then return 'st' end
  if n % 10 == 2 and n ~= 12 then return 'nd' end
  if n % 10 == 3 and n ~= 13 then return 'rd' end
  return 'th'
end
function formatSnap(n)
  local div = getDivision(n)
  return tostring(div) .. suffixSnap(div)
end

---@param str string
---@param len number
---@param char string?
function lpad(str, len, char)
  char = char or ' '
  return string.rep(char, len - #str) .. str
end

---@param t number
function formatTime(t)
  t = math.max(t, 0)
  return
    lpad(tostring(math.floor(t / 60)), 2, '0') .. ':' ..
    lpad(tostring(math.floor(t % 60)), 2, '0') .. '.' ..
    lpad(tostring(math.floor((t * 100) % 100)), 2, '0')
end

---@param o any
function pretty(o, depth, seen)
  depth = depth or 0
  if depth > 4 then
    return '...'
  end
  seen = seen and copy(seen) or {}
  --print(depth, countKeys(seen))
  if type(o) == 'table' then
    if seen[o] then return '(circular)' end
    seen[o] = true
    local keys = countKeys(o)
    local onlyNumbers = true
    for i = 1, keys do
      if rawget(o, i) == nil then
        onlyNumbers = false
        break
      end
    end

    local str = ''
    local linebreaks = false
    local nPos = 0

    if onlyNumbers then
      for i, v in ipairs(o) do
        local s = pretty(v, depth + 1, seen)
        if string.find(s, '\n') or (#str - nPos + #s + depth * 2) > 40 then
          linebreaks = true
          str = str .. '\n'
          str = str .. string.rep('  ', depth)
          nPos = #str
        end
        str = str .. s .. ', '
      end
    else
      for k, v in pairs(o) do
        local ks = (type(k) == 'string' and string.find(k, '^[a-zA-Z0-9_]+$')) and k or ('[' .. pretty(k, depth + 1, seen) .. ']')
        local vs = pretty(v, depth + 1, seen)
        local s = ks .. ' = ' .. vs
        local nPos = (string.find(str, '\n') or 0)
        if string.find(s, '\n') or (#str - nPos + #s + depth * 2) > 40 then
          linebreaks = true
          str = str .. '\n'
          str = str .. string.rep('  ', depth)
          nPos = #str
        end

        str = str .. s .. ', '
      end
    end

    str = string.sub(str, 1, #str - 2)

    if linebreaks then
      if string.sub(str, 1, 1) ~= '\n' then
        str = '\n' .. string.rep('  ', depth) .. str
      end
      str = str .. '\n' .. string.rep('  ', depth - 1) .. '}'
    else
      str = str .. ' }'
    end

    return '{ ' .. str
  elseif type(o) == 'string' then
    return string.format('%q', o)
    --if string.find(o, '\n') then
    --  return '[[' .. string.gsub(o, '\\', '\\\\') .. ']]'
    --else
    --  return '"' .. string.gsub(string.gsub(o, '\\', '\\\\'), '"', '\\"') .. '"'
    --end
  elseif type(o) == 'nil' then
    return 'nil'
  else
    return tostring(o)
  end
end

-- returns true if every value in tab1 matches tab2, and not necessarily the other way round
function looseComp(tab1, tab2)
  for k, v1 in pairs(tab1) do
    local v2 = tab2[k]
    if type(v1) ~= type(v2) then return false end
    if type(v1) == 'table' then
      if not looseComp(v1, v2) then return false end
    else
      if v1 ~= v2 then return false end
    end
  end
  return true
end


---@generic T
---@param t table<T>
---@param e T
---@return boolean
function includes(t, e)
  for i = 1, #t do
    if t[i] == e then
      return true
    end
  end
  return false
end

-- hacky slow and awful. use in moderation
---@param thing XDRVThing
function getThingType(thing)
  for k in pairs(thing) do
    if k ~= 'beat' then return k end
  end
end

---@param x number
---@return number
function sign(x)
  if x > 0 then return 1 end
  if x < 0 then return -1 end
  return 0
end

function screenCoords()
  local sw, sh = love.graphics.getDimensions()
  return sw, sh, sw/2, sh/2
end

---@param font love.Font
---@param text string
---@param width number
---@param align love.AlignMode?
function newWrapText(font, text, width, align)
  local t = love.graphics.newText(font, '')
  t:setf(text, width, align or 'center')
  return t
end

function titleCase(str)
  return string.upper(string.sub(str, 1, 1)) .. string.lower(string.sub(str, 2))
end

---@generic K, V
---@param tab table<V, K>
---@param v V
---@return K?
function findIndex(tab, v)
  for k, v2 in pairs(tab) do
    if v2 == v then
      return k
    end
  end
end

---@generic A table<any>
---@generic B table<any>
---@param tab1 A
---@param tab2 B
---@return B
function merge(tab1, tab2)
  local tab = {}
  for k, v in pairs(tab1) do
    tab[k] = v
  end
  for k, v in pairs(tab2) do
    if type(v) == 'table' and type(tab[k]) == 'table' then
      tab[k] = merge(tab[k], v)
    elseif v ~= nil then
      tab[k] = v
    end
  end
  return tab
end