local M = {}

local SEGMENT_INCR = 1 -- beats

local function gcd(m, n)
  while n ~= 0 do
    local q = m
    m = n
    n = q % n
  end
  return m
end

local function lcm(m, n)
  return ( m ~= 0 and n ~= 0 ) and m * n / gcd( m, n ) or 0
end

local function quantize(b)
  if b > 0.5 then
    return math.floor((1 / (1 - b)) + 0.5)
  end
  return math.floor((1 / b) + 0.5)
end

---@enum XDRVLane
M.XDRVLane = {
  Left = 1,
  Right = 2,
}

---@alias XDRVNoteColumn 1 | 2 | 3 | 4 | 5 | 6

---@alias XDRVNote { beat: number, note: { column: XDRVNoteColumn, length: number? } }
---@alias XDRVHoldStart { beat: number, holdStart: { column: XDRVNoteColumn } }
---@alias XDRVHoldEnd { beat: number, holdEnd: { column: XDRVNoteColumn } }
---@alias XDRVGearShift { beat: number, gearShift: { lane: XDRVLane, length: number } }
---@alias XDRVGearShiftStart { beat: number, gearShiftStart: { lane: XDRVLane } }
---@alias XDRVGearShiftEnd { beat: number, gearShiftEnd: { lane: XDRVLane } }
---@alias XDRVEvent XDRVNote | XDRVHoldStart | XDRVHoldEnd | XDRVGearShift | XDRVGearShiftStart | XDRVGearShiftEnd

---@param events XDRVEvent[]
---@return XDRVEvent[]
local function addHoldEnds(events)
  local newEvents = {}
  for _, event in ipairs(events) do
    if event.note and event.note.length then
      table.insert(newEvents, { beat = event.beat, holdStart = { column = event.note.column } })
      table.insert(newEvents, { beat = event.beat + event.note.length, holdEnd = { column = event.note.column } })
    elseif event.gearShift then
      table.insert(newEvents, { beat = event.beat, gearShiftStart = { lane = event.gearShift.lane } })
      table.insert(newEvents, { beat = event.beat + event.gearShift.length, gearShiftEnd = { lane = event.gearShift.lane } })
    else
      table.insert(newEvents, event)
    end
  end
  return newEvents
end
---@param events XDRVEvent[]
---@return XDRVEvent[]
local function collapseHoldEnds(events)
  local indices = {}
  local insertIndices = {}

  local newEvents = {}

  for i, event in ipairs(events) do
    if event.holdStart then
      local column = event.holdStart.column
      indices[column] = i
      insertIndices[column] = #newEvents + 1
    elseif event.gearShiftStart then
      local column = -event.gearShiftStart.lane
      indices[column] = i
      insertIndices[column] = #newEvents + 1
    elseif event.holdEnd then
      local column = event.holdEnd.column
      local start = indices[column]
      local insert = insertIndices[column]
      if start then
        table.insert(newEvents, insert, {
          beat = events[start].beat,
          note = {
            column = column,
            length = event.beat - events[start].beat
          }
        })
        for k, v in pairs(insertIndices) do
          insertIndices[k] = v + 1
        end
      end
    elseif event.gearShiftEnd then
      local lane = event.gearShiftEnd.lane
      local column = -lane
      local start = indices[column]
      local insert = insertIndices[column]
      if start then
        table.insert(newEvents, insert, {
          beat = events[start].beat,
          gearShift = {
            lane = lane,
            length = event.beat - events[start].beat
          }
        })
        for k, v in pairs(insertIndices) do
          insertIndices[k] = v + 1
        end
      end
    else
      table.insert(newEvents, event)
    end
  end

  return newEvents
end

---@param event XDRVEvent
local function noteEventToType(event)
  if not event then return '0' end
  if event.note then return '1' end
  if event.holdStart then return '2' end
  if event.holdEnd then return '4' end
  return '0'
end
---@param c table<number, XDRVEvent>
local function formatNotesCol(c)
  return
    noteEventToType(c[1]) ..
    noteEventToType(c[2]) ..
    noteEventToType(c[3]) .. '-' ..
    noteEventToType(c[4]) ..
    noteEventToType(c[5]) ..
    noteEventToType(c[6])
end
local function noteEvent(beat, s, c)
  if s == '1' then
    return { beat = beat, note = { column = c } }
  end
  if s == '2' then
    return { beat = beat, holdStart = { column = c } }
  end
  if s == '4' then
    return { beat = beat, holdEnd = { column = c } }
  end
  return nil
end
local function gearShiftEvent(beat, s, lane)
  if s == '1' then
    return { beat = beat, gearShiftStart = { lane = lane } }
  end
  if s == '2' then
    return { beat = beat, gearShiftEnd = { lane = lane } }
  end
  return nil
end

---@param events XDRVEvent[]
local function serializeChart(events)
  events = addHoldEnds(events)

  local segments = {}

  local b = 0
  local eventIdx = 1
  while true do
    if eventIdx > #events then break end

    ---@type XDRVEvent[]
    local segment = {}
    local add = 0
    for i = eventIdx, #events do
      local event = events[i]
      if event.beat >= (b + SEGMENT_INCR) then
        break
      end
      add = add + 1
      if event.beat >= b then
        table.insert(segment, event)
      end
    end
    eventIdx = eventIdx + add

    local rowsN = 1
    for _, event in ipairs(segment) do
      if event.beat > b then
        rowsN = lcm(rowsN, quantize(event.beat - b))
      end
    end
    --print('-> ', #segment, rowsN)

    local segmentStr = {}

    --print(#segment .. ' in segment')

    for row = 1, rowsN do
      local offset = (row - 1) / rowsN

      local cols = {}

      for i, event in ipairs(segment) do
        if math.abs(event.beat - (b + offset)) < 0.001 then
          if event.note or event.holdStart or event.holdEnd then
            local note = event.note or event.holdStart or event.holdEnd
            cols[note.column] = event
          elseif event.label then
            if string.sub(event.label, 1, 1) == '#' then
              table.insert(segmentStr, event.label)
            else
              table.insert(segmentStr, '#LABEL=' .. event.label)
            end
          elseif event.timesig then
            table.insert(segmentStr, '#TIME_SIGNATURE=' .. event.timesig[1] .. ',' .. event.timesig[2])
          elseif event.bpm then
            table.insert(segmentStr, '#BPM=' .. event.bpm)
          elseif event.warp then
            table.insert(segmentStr, '#WARP=' .. event.warp)
          elseif event.stop then
            table.insert(segmentStr, '#STOP_SECONDS=' .. event.stop)
          elseif event.fake then
            table.insert(segmentStr, '#FAKE=' .. event.fake)
          end
        end
      end

      table.insert(segmentStr, formatNotesCol(cols) .. '|' .. '00' .. '|' .. '0')
    end

    --print(table.concat(segmentStr, '\n'))

    table.insert(segments, table.concat(segmentStr, '\n'))

    b = b + SEGMENT_INCR
  end

  return '--\n' .. table.concat(segments, '\n--\n') .. '\n--'
end

function M.serialize(chart)
  return '// Metadata NYI\n' .. serializeChart(chart.chart)
end

---@return XDRVEvent[]
local function deserializeChart(str)
  local events = {}

  local parsePos = 1

  local b = 0

  while true do
    local pos, off = string.find(str, '\r?\n--\r?\n', parsePos)

    if not pos then pos = #str + 3 end

    local segment = string.sub(str, parsePos, pos - 3)

    local rows = {}
    local buffer = {}

    for line in string.gmatch(segment, '[^\r\n]+') do
      local isEvent = string.sub(line, 1, 1) == '#'
      if string.len(line) ~= 0 and line ~= '--' then
        table.insert(buffer, line)
        if not isEvent then
          table.insert(rows, buffer)
          buffer = {}
        end
      end
    end

    for rowI, row in ipairs(rows) do
      local div = (rowI - 1) / #rows
      local b = b + div
      for n = 1, #row - 1 do
        -- this will only have events
        -- TODO
      end
      local noterow = row[#row]
      local c1, c2, c3, c4, c5, c6, l, r, d = string.match(noterow, '(%d)(%d)(%d)%-(%d)(%d)(%d)|(%d)(%d)|(%d)')
      if c1 then
        for column, s in ipairs({c1, c2, c3, c4, c5, c6}) do
          local ev = noteEvent(b, s, column)
          if ev then table.insert(events, ev) end
        end
        for lane, gear in ipairs({l, r}) do
          local ev = gearShiftEvent(b, gear, lane)
          if ev then table.insert(events, ev) end
        end
      end
    end

    if off then
      parsePos = off + 1
      b = b + SEGMENT_INCR
    else
      break
    end
  end

  return collapseHoldEnds(events)
end

---@enum XDRVDifficulty
M.XDRVDifficulty = {
  Beginner = 0,
  Normal = 1,
  Hyper = 2,
  Extreme = 3,
}

---@class XDRVMetadata @ https://github.com/Dylannichols702/SCXEditor/blob/d3339f664c739a3d7d9120c8411192bbb3a1779a/SCXEditor/SCXEditor/Models/XDRV/XDRV.cs#L465
---@field musicTitle string @ MUSIC_TITLE
---@field alternateTitle string @ ALTERNATE_TITLE
---@field musicArtist string @ MUSIC_ARTIST
---@field musicAudio string @ MUSIC_AUDIO
---@field jacketImage string @ JACKET_IMAGE
---@field jacketIllustrator string @ JACKET_ILLUSTRATOR
---@field chartAuthor string @ CHART_AUTHOR
---@field chartUnlock string @ CHART_UNLOCK
---@field stageBackground string @ STAGE_BACKGROUND
---@field modfilePath string @ MODFILE_PATH
---@field chartLevel number @ CHART_LEVEL
---@field chartDisplayBPM number @ CHART_DISPLAY_BPM
---@field chartBoss boolean @ CHART_BOSS
---@field disableLeaderboardUploading boolean @ DISABLE_LEADERBOARD_UPLOADING
---@field rpcHidden boolean @ RPC_HIDDEN
---@field isFlashTrack boolean @ FLASH_TRACK
---@field isKeyboardOnly boolean @ KEYBOARD_ONLY
---@field isOriginal boolean @ ORIGINAL
---@field musicPreviewStart number @ MUSIC_PREVIEW_START
---@field musicPreviewLength number @ MUSIC_PREVIEW_LENGTH
---@field musicVolume number @ MUSIC_VOLUME
---@field musicOffset number @ MUSIC_OFFSET
---@field chartBPM number @ CHART_BPM
---@field chartTags { [1]: number, [2]: number, [3]: number, [4]: number } @ CHART_TAGS
---@field chartDifficulty XDRVDifficulty @ CHART_DIFFICULTY

local function parseString(s)
  if type(s) ~= 'string' then return '' end
  return s
end

local function parseFloat(s)
  return tonumber(s) or -1
end

-- https://love2d.org/forums/viewtopic.php?p=208676&sid=3b643938f0769ccacdc44af3ea34f09c#p208676
local function round(n) return n >= 0 and n - n % -1 or n - n % 1 end
local function parseInt(s)
  return round(parseFloat(s))
end

local function parseBool(s)
  return s == 'TRUE'
end

local function parseDifficulty(s)
  if s == 'BEGINNER' then return M.XDRVDifficulty.Beginner end
  if s == 'NORMAL' then return M.XDRVDifficulty.Normal end
  if s == 'HYPER' then return M.XDRVDifficulty.Hyper end
  if s == 'EXTREME' then return M.XDRVDifficulty.Extreme end

  return M.XDRVDifficulty.Beginner
end

---@param m table<string, string>
---@return XDRVMetadata
local function makeMetdata(m)
  return {
    musicTitle = parseString(m.MUSIC_TITLE),
    alternateTitle = parseString(m.ALTERNATE_TITLE),
    musicArtist = parseString(m.MUSIC_ARTIST),
    musicAudio = parseString(m.MUSIC_AUDIO),
    jacketImage = parseString(m.JACKET_IMAGE),
    jacketIllustrator = parseString(m.JACKET_ILLUSTRATOR),
    chartAuthor = parseString(m.CHART_AUTHOR),
    chartUnlock = parseString(m.CHART_UNLOCK),
    stageBackground = parseString(m.STAGE_BACKGROUND),
    modfilePath = parseString(m.MODFILE_PATH),
    chartLevel = parseInt(m.CHART_LEVEL),
    chartDisplayBPM = parseInt(m.CHART_DISPLAY_BPM),
    chartBoss = parseBool(m.CHART_BOSS),
    disableLeaderboardUploading = parseBool(m.DISABLE_LEADERBOARD_UPLOADING),
    rpcHidden = parseBool(m.RPC_HIDDEN),
    isFlashTrack = parseBool(m.FLASH_TRACK),
    isKeyboardOnly = parseBool(m.KEYBOARD_ONLY),
    isOriginal = parseBool(m.ORIGINAL),
    musicPreviewStart = parseFloat(m.MUSIC_PREVIEW_START),
    musicPreviewLength = parseFloat(m.MUSIC_PREVIEW_LENGTH),
    musicVolume = parseFloat(m.MUSIC_VOLUME),
    musicOffset = parseFloat(m.MUSIC_OFFSET),
    chartBPM = parseFloat(m.CHART_BPM),
    chartTags = { 0, 0, 0, 0 }, -- TODO
    chartDifficulty = parseDifficulty(m.CHART_DIFFICULTY),
  }
end

local function deserializeMetadata(str)
  local metadata = {}

  for line in string.gmatch(str, '[^\r\n]+') do
    if string.len(line) ~= 0 and string.sub(line, 1, 2) ~= '//' then
      local eq = string.find(line, '=')
      if eq then
        local key = string.sub(line, 1, eq - 1)
        local value = string.sub(line, eq + 1)

        metadata[key] = value
      end
    end
  end

  return makeMetdata(metadata)
end

---@alias XDRVChart { metadata: XDRVMetadata, chart: XDRVEvent[] }

---@return XDRVChart
function M.deserialize(str)
  local chartStart = string.find(str, '\r?\n--\r?\n')
  if not chartStart then
    return {
      metadata = deserializeMetadata(str)
    }
  end

  local meta = string.sub(str, 1, chartStart - 1)
  local chart = string.sub(str, chartStart + 1)

  return {
    metadata = deserializeMetadata(meta),
    chart = deserializeChart(chart)
  }
end

return M