local sm = {}

local function filterComments(text)
  local lines = {}
  for line in string.gmatch(text, '([^\n\r]*)[\n\r]?') do
    if not string.match(line, '^%s*//.+') and string.len(line) > 0 then
      table.insert(lines, line)
    end
  end
  return table.concat(lines, '\n')
end

local function chartToNotedata(text)
  local measures = {}
  for measure in string.gmatch(text, '%s*([^,]*)%s*,?') do
    local lines = {}
    for line in string.gmatch(measure, '%s*([^\n\r]*)%s*[\n\r]?') do
      if line ~= '' then
        table.insert(lines, line)
      end
    end
    table.insert(measures, lines)
  end

  local notedata = {}

  for i, measure in ipairs(measures) do
    local precision = 1/#measure
    local measureBeat = (i - 1) * 4
    for row, notes in ipairs(measure) do
      local beat = measureBeat + (row - 1) * precision * 4
      local column = 0
      for note in string.gmatch(notes, '%S') do
        if note ~= '0' then
          table.insert(notedata, {beat, column, note})
        end
        column = column + 1
      end
    end
  end

  return notedata
end

local parsers = {}

local function numParser(n)
  return tonumber(n)
end
local function boolParser(n)
  return n == 'YES'
end

function parsers.NOTES(value)
  local chunks = {}
  for chunk in string.gmatch(value, '%s*([^:]*)%s*:?') do
    table.insert(chunks, chunk)
  end

  return {
    type = chunks[1],
    credit = chunks[2],
    difficulty = chunks[3],
    rating = chunks[4],
    grooveRadar = chunks[5],
    notes = chartToNotedata(chunks[6]),
  }
end

local function listParser(value)
  local values = {}

  local segments = {}
  for v in string.gmatch(value .. ',', '(.-),') do
    --print(v)
    local key, value = string.match(v, '([%d.]+)=(.+)')
    --print(key, value)
    if key and value then
      if #segments > 1 then
        local mergedValue = table.concat(segments, ',')
        --print(mergedValue)
        local keyNew, valueNew = string.match(mergedValue, '([%d.]+)=(.+)')
        if keyNew and valueNew then
          table.remove(values, #values)
          table.insert(values, {tonumber(keyNew), valueNew})
          --print('/ ', keyNew, valueNew)
        end
      end
      segments = { v }
      --print('+ ', key, value)
      table.insert(values, {tonumber(key), value})
    else
      table.insert(segments, v)
    end
  end

  if #segments > 1 then
    local mergedValue = table.concat(segments, ',')
    --print(mergedValue)
    local keyNew, valueNew = string.match(mergedValue, '([%d.]+)=(.+)')
    if keyNew and valueNew then
      table.remove(values, #values)
      table.insert(values, {tonumber(keyNew), valueNew})
      --print('/ ', keyNew, valueNew)
    end
  end

  return values
end

local function numListParser(value)
  local values = {}

  for _, n in ipairs(listParser(value)) do
    table.insert(values, {n[1], tonumber(n[2])})
  end

  return values
end

parsers.BPMS = numListParser

function parsers.TIMESIGNATURES(value)
  local sigs = {}

  for _, n in ipairs(listParser(value)) do
    local _, _, a, b = string.find(n[2], '([%d.]+)=([%d.]+)')
    table.insert(sigs, {n[1], a, b})
  end

  return sigs
end

parsers.LABELS = listParser
parsers.WARPS = numListParser
parsers.DELAYS = numListParser
parsers.STOPS = numListParser
parsers.FAKES = numListParser

parsers.OFFSET = numParser
parsers.SELECTABLE = boolParser
parsers.SAMPLELENGTH = numParser
-- cathy-specific
--parsers.ANNOUNCE = boolParser
--parsers.LOOP = boolParser

local function idxm(k, v)
  if type(k) ~= 'table' then
    return k
  else
    return k[v]
  end
end

function sm.parse(text, isSSC)
  -- initial parse pass

  local res = {}
  for key, value in string.gmatch(text, '#([A-Z]-):(.-);') do
    value = filterComments(value)
    if res[key] and type(res[key]) ~= 'table' then
      res[key] = {res[key], value}
    elseif res[key] and type(res[key]) == 'table' then
      table.insert(res[key], value)
    else
      res[key] = value
    end
  end

  -- specialized parsers

  for key, value in pairs(res) do
    if type(value) == 'table' then
      for i, v in ipairs(value) do
        local parser = parsers[key]
        if parser and not (key == 'NOTES' and isSSC) then
          res[key][i] = parser(v)
        end
      end
    else
      local parser = parsers[key]
      if parser and not (key == 'NOTES' and isSSC) then
        res[key] = parser(value)
      end
    end
  end

  if res.NOTES then
    if res.NOTES.notes then
      res.NOTES = {res.NOTES}
    end
  end

  if isSSC then
    local compatNotes = {}
    if type(res.NOTES) == 'string' then
      res.NOTES = { res.NOTES }
    end
    for i, c in ipairs(res.NOTES) do
      table.insert(compatNotes, {
        type = idxm(res.STEPSTYPE, i),
        credit = idxm(res.DESCRIPTION, i),
        difficulty = idxm(res.DIFFICULTY, i),
        rating = idxm(res.METER, i),
        grooveRadar = idxm(res.RADARVALUES, i),
        notes = chartToNotedata(c),
      })
    end
    res.NOTES = compatNotes
  end

  if res.NOTES and #res.NOTES > 0 then
    print('loaded track ' .. (res.MUSIC or '???') .. ' w/ ' .. (res.NOTES and #res.NOTES or 0) .. ' charts:')
    for _, v in ipairs(res.NOTES) do
      print('  ' .. v.credit .. ': ' .. #v.notes .. ' notes [' .. v.type .. ']')
    end
  else
    print('loaded track ' .. (res.MUSIC or '???'))
  end

  return res
end

function sm.notedataToColumns(data)
  local columns = {}
  for _, note in ipairs(data) do
    columns[note[2]] = columns[note[2]] or {}
    table.insert(columns[note[2]], note[1])
  end
  return columns
end

return sm