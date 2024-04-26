function copy(tab)
  return {unpack(tab)}
end

function countKeys(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
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