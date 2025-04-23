local config        = require 'src.config'
local easeFunctions = require 'lib.ease'
local conductor     = require 'src.conductor'
local xdrv          = require 'lib.xdrv'
local logs          = require 'src.logs'
local xdrvColors    = require 'src.xdrvcolors'
local sort          = require 'lib.sort'
local sandbox       = require 'lib.sandbox'

local easeFunctionsLower = {}
for k, v in pairs(easeFunctions) do easeFunctionsLower[string.lower(k)] = v end

local self = {}

function self.getScrollSpeed(beat)
  if not config.config.previewMode then return 1 end
  if not chart.chart then return 1 end

  local speed = self.getModValue('speed')
  return speed
end

---@class ArgSet
local ArgSet = {}

function ArgSet:push(...)
  for _, v in ipairs({...}) do
    table.insert(self, v)
  end
end

function ArgSet:getValue(idx, expect, nillable)
  local value = rawget(self, idx)
  if value == nil and nillable then
    return nil
  end
  local got = type(value)
  if got ~= expect then
    error('expected arg #' .. idx .. ' to be ' .. expect .. ', got ' .. got, 0)
  end
  return value
end

function ArgSet:getNumber(idx, nillable)
  return self:getValue(idx, 'number', nillable)
end
function ArgSet:getString(idx, nillable)
  return self:getValue(idx, 'string', nillable)
end
function ArgSet:getBoolean(idx, nillable)
  return self:getValue(idx, 'boolean', nillable)
end

ArgSet.__index = ArgSet

function ArgSet.new()
  return setmetatable({}, ArgSet)
end

---@class StringArgSet : ArgSet
local StringArgSet = {}

function StringArgSet:push(...)
  for _, v in ipairs({...}) do
    if type(v) ~= 'string' then
      error('expected string but passed a ' .. type(v), 2)
    end
    table.insert(self, v)
  end
end

function StringArgSet:getValue(idx, expect, nillable)
  error('not implemented', 2)
end

function StringArgSet:getNumber(idx, nillable)
  local value = rawget(self, idx)
  if value == nil then
    if not nillable then error('expected arg #' .. idx .. ' to be number, got nil', 0) end
    return nil
  end
  local num = tonumber(value)
  if num == nil then
    error('expected arg #' .. idx .. ' to be number, got `' .. value .. '`' , 0)
  end
  return num
end
function StringArgSet:getString(idx, nillable)
  local value = rawget(self, idx)
  if value == nil then
    if not nillable then error('expected arg #' .. idx .. ' to be string, got nil', 0) end
    return nil
  end
  return value
end
function StringArgSet:getBoolean(idx, nillable)
  local value = rawget(self, idx)
  if value == nil then
    if not nillable then error('expected arg #' .. idx .. ' to be boolean, got nil', 0) end
    return nil
  end
  if value == 'true' then
    return true
  end
  if value == 'false' then
    return false
  end
  error('expected arg #' .. idx .. ' to be boolean, got `' .. value .. '`' , 0)
end

StringArgSet.__index = StringArgSet

function StringArgSet.new()
  return setmetatable({}, StringArgSet)
end

---@param value any @ value given
---@param index number @ argument index
---@param typee string @ expected type
---@param nillable boolean? @ if nil is ok to pass
---@param layer number? @ added to the error() call
local function checkArg(value, index, typee, nillable, layer)
  if value == nil and nillable then
    return
  end
  if type(value) ~= typee then
    error('expected arg #' .. index .. ' to be ' .. typee .. ', got ' .. type(value), layer or 3)
  end
end
local warned = {}
local function warn(msg, source)
  if not source then
    local info = debug.getinfo(3, 'lS')
    source = string.gsub(info.short_src, '%[string "(.-)"%]', '%1') .. ':' .. info.currentline
  end
  local s = source .. msg
  if warned[s] then return end
  warned[s] = true
  logs.warn('Warning: ' .. source .. ': ' .. msg)
end

---@alias Ease { target: string, startValue: number?, value: number, dur: number, time: boolean, ease: fun(a: number): number }
---@alias TimedEase { beat: number?, time: number?, ease: Ease }

---@type TimedEase[]
local eases = {}
---@type TimedEase[]
local activeEases = {}
---@type TimedEase[]
local inactiveEases = {}
---@type XDRVMeasureLine[]
local measureLines = {}
local knownModNames = {}

local function easeSort(a, b)
  if a.beat and b.beat then return a.beat < b.beat end
  if a.time and b.time then return a.time < b.time end
  if a.beat then
    return a.beat < conductor.beatAtTime(b.time)
  end
  if a.time then
    return conductor.beatAtTime(a.time) < b.beat
  end
  error('What? huh? is anyone there?')
end

local function genericSetConst(target, value)
  return function() return {
    target = target,
    value = value,
    dur = 0,
    time = false,
    ease = easeFunctions.Instant,
  } end
end

local function genericSet(target)
  ---@param args ArgSet
  return function(args)
    local alpha = args:getNumber(1)
    return {
      target = target,
      value = alpha,
      dur = 0,
      time = false,
      ease = easeFunctions.Instant,
    }
  end
end
local function genericEase(target)
  ---@param args ArgSet
  return function(args)
    local alpha = args:getNumber(1)
    local dur = args:getNumber(2)
    local time = args:getBoolean(3, true)
    local ease = args:getString(4, true)
    local easeFunction = easeFunctionsLower[string.lower(ease or 'InOutSine')]
    if not easeFunction then
      error('no such ease ' .. ease, 0)
    end
    return {
      target = target,
      value = alpha,
      dur = dur,
      time = time or false,
      ease = easeFunction,
    }
  end
end

-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/global.md
-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/tunnel.md
-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/city.md
---@type table<string, fun(args: ArgSet): Ease>
local easeConverters = {
  EnableBloomBeat = genericSetConst('BloomBeat', 1),
  DisableBloomBeat = genericSetConst('BloomBeat', 0),

  SetBloomIntensity = genericSet('BloomIntensity'),
  SetBloomDiffusion = genericSet('BloomDiffusion'),

  EaseBloomIntensity = genericEase('BloomIntensity'),
  EaseBloomDiffusion = genericEase('BloomDiffusion'),

  SetPathAlpha = genericSet('PathAlpha'),
  SetLeftPathAlpha = genericSet('LeftPathAlpha'),
  SetRightPathAlpha = genericSet('RightPathAlpha'),

  EasePathAlpha = genericEase('PathAlpha'),
  EaseLeftPathAlpha = genericEase('LeftPathAlpha'),
  EaseRightPathAlpha = genericEase('RightPathAlpha'),
}

local defaultValues = {
  PathAlpha = 1,
  LeftPathAlpha = 1,
  RightPathAlpha = 1,
  BloomIntensity = 1,
  BloomDiffusion = 1,

  -- https://github.com/tari-cat/XDRV/blob/main/Assets/Scripts/XDRVEditorScripts/Mods.cs#L692
  mod_speed = 1,
  mod_camera_fov = 100,
  mod_lane_color_red = 0.075,
  mod_lane_color_green = 0.075,
  mod_lane_color_blue = 0.075,
  mod_lane_color_alpha = 1,
  mod_note_scale_x = 1,
  mod_note1_scale_x = 1,
  mod_note2_scale_x = 1,
  mod_note3_scale_x = 1,
  mod_note4_scale_x = 1,
  mod_note5_scale_x = 1,
  mod_note6_scale_x = 1,
  mod_note_scale_y = 1,
  mod_note1_scale_y = 1,
  mod_note2_scale_y = 1,
  mod_note3_scale_y = 1,
  mod_note4_scale_y = 1,
  mod_note5_scale_y = 1,
  mod_note6_scale_y = 1,
  mod_note_scale_z = 1,
  mod_note1_scale_z = 1,
  mod_note2_scale_z = 1,
  mod_note3_scale_z = 1,
  mod_note4_scale_z = 1,
  mod_note5_scale_z = 1,
  mod_note6_scale_z = 1,
}

local aliases = {
  mod_camera_move_x = 'mod_camera_position_x',
  mod_camera_move_y = 'mod_camera_position_y',
  mod_camera_move_z = 'mod_camera_position_z',
  mod_camera_rotate_x = 'mod_camera_rotation_x',
  mod_camera_rotate_y = 'mod_camera_rotation_y',
  mod_camera_rotate_z = 'mod_camera_rotation_z',
  mod_camera_field_of_vision = 'mod_camera_fov',
  mod_track_rotate_x = 'mod_track_rotation_x',
  mod_track_rotate_y = 'mod_track_rotation_y',
  mod_track_rotate_z = 'mod_track_rotation_z',
  mod_trackleft_rotate_x = 'mod_trackleft_rotation_x',
  mod_trackleft_rotate_y = 'mod_trackleft_rotation_y',
  mod_trackleft_rotate_z = 'mod_trackleft_rotation_z',
  mod_trackright_rotate_x = 'mod_trackright_rotation_x',
  mod_trackright_rotate_y = 'mod_trackright_rotation_y',
  mod_trackright_rotate_z = 'mod_trackright_rotation_z',
}

local lastBeat = 9e9
local valuesBuffer = {}
local easedValuesBuffer = {}

---@param type string
---@param beat number?
---@return number
function self.getEasedValue(type, beat)
  if not config.config.previewMode then
    return defaultValues[type] or 0
  end

  beat = beat or conductor.beat
  local time = conductor.timeAtBeat(beat)

  if beat < lastBeat then
    -- reset
    inactiveEases = {}
    activeEases = {}
    for _, ease in ipairs(eases) do
      table.insert(activeEases, ease)
    end
    valuesBuffer = {}
    easedValuesBuffer = {}
  elseif beat == lastBeat then
    -- just return the cached values
    return easedValuesBuffer[type] or valuesBuffer[type] or defaultValues[type] or 0
  end

  lastBeat = beat

  local removeIndices = {}
  for i = 1, #activeEases do
    local ease = activeEases[i]
    --print(i, ease.beat, ease.ease.target, ease.ease.value)
    if (ease.beat and ease.beat > beat) or (ease.time and ease.time > time) then break end

    local target = aliases[ease.ease.target] or ease.ease.target

    local a = 1
    if ease.ease.dur > 0 then
      a = ((ease.time and time or beat) - (ease.time and ease.time or ease.beat)) / ease.ease.dur
    end

    local easeValue = mix(ease.ease.startValue or valuesBuffer[target] or defaultValues[target] or 0, ease.ease.value, ease.ease.ease(clamp(a, 0, 1)))
    easedValuesBuffer[target] = easeValue

    if (ease.time and time or beat) >= ((ease.time and ease.time or ease.beat) + ease.ease.dur) then
      valuesBuffer[ease.ease.target] = ease.ease.value
      table.insert(removeIndices, i)
      table.insert(inactiveEases, ease)
    end
  end
  for i = #removeIndices, 1, -1 do
    local index = removeIndices[i]
    table.remove(activeEases, index)
  end

  return easedValuesBuffer[type] or valuesBuffer[type] or defaultValues[type] or 0
end
function self.getModValue(type)
  return self.getEasedValue('mod_' .. type)
end

function self.getMeasureLines()
  return measureLines
end

-- !! WILL ERROR IN YOUR FACE !!
---@param beat number?
---@param time number?
---@param name string
---@param args ArgSet
local function addEvent(beat, time, name, args)
  local conv = easeConverters[name]
  if not conv then return end
  local ease = conv(args)

  if ease.time and not time then
    time = conductor.timeAtBeat(beat)
    beat = nil
  elseif not ease.time and not beat then
    beat = conductor.beatAtTime(time)
    time = nil
  end

  table.insert(eases, {
    beat = beat,
    time = time,
    ease = ease,
  })
end

---@param lane XDRVLane
function self.getPathAlpha(lane)
  if lane == xdrv.XDRVLane.Left then
    return self.getEasedValue('LeftPathAlpha') * self.getEasedValue('PathAlpha')
  else
    return self.getEasedValue('RightPathAlpha') * self.getEasedValue('PathAlpha')
  end
end

---@param lane XDRVLane
function self.getPathBloom(lane)
  return self.getEasedValue('BloomBeat')
    * (1 - easeFunctions.OutQuad(conductor.beat % 1)) * 0.5
    -- since we're faking bloom (for now), just multiply both of them, fuck it
    * self.getEasedValue('BloomIntensity')
    * self.getEasedValue('BloomDiffusion')
    * self.getPathAlpha(lane)
end

local function getNotePosAxis(column, axis)
  return self.getModValue('note' .. column .. '_move_' .. axis) + self.getModValue('note' .. '_move_' .. axis)
end
---@param column number
function self.getNotePos(column)
  local str = column and tostring(column) or ''
  return getNotePosAxis(str, 'x'), getNotePosAxis(str, 'y'), getNotePosAxis(str, 'z')
end
local function getNoteScaleAxis(column, axis)
  return self.getModValue('note' .. column .. '_scale_' .. axis) * self.getModValue('note' .. '_scale_' .. axis)
end
---@param column number
function self.getNoteScale(column)
  local str = column and tostring(column) or ''
  return getNoteScaleAxis(str, 'x'), getNoteScaleAxis(str, 'y'), getNoteScaleAxis(str, 'z')
end

local fauxXDRV = {}

function fauxXDRV.RunEvent(eventName, b, c, ...)
  checkArg(eventName, 1, 'string')

  local beatOrTime, timingValue = b, c
  if type(c) == 'string' and type(b) == 'number' then
    beatOrTime, timingValue = c, b
    checkArg(timingValue, 2, 'number')
  else
    checkArg(timingValue, 3, 'number')
  end
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    warn('beatOrTime arg is neither \'beat\' nor \'time\', but \'' .. tostring(beatOrTime) .. '\'')
  end

  local time = beatOrTime == 'time'

  local args = ArgSet.new()
  args:push(...)

  local ok, res = pcall(addEvent,
    (not time) and timingValue or nil,
    time and timingValue or nil,
    eventName,
    args
  )

  if not ok then
    error('Error adding event: ' .. res, 2)
  end
end
fauxXDRV.run_event = fauxXDRV.RunEvent

function fauxXDRV.AddMeasureLine(a, b, lane)
  local beatOrTime, timingValue = a, b
  if type(b) == 'string' and type(a) == 'number' then
    beatOrTime, timingValue = b, a
    checkArg(timingValue, 1, 'number')
  else
    checkArg(timingValue, 2, 'number')
  end
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    warn('beatOrTime arg is neither \'beat\' nor \'time\', but \'' .. tostring(beatOrTime) .. '\'')
  end

  local time = beatOrTime == 'time'
  local beat = timingValue
  if time then
    beat = conductor.beatAtTime(timingValue)
  end
  table.insert(measureLines, { beat = beat, measureLine = lane or -1 })
end
fauxXDRV.add_measure_line = fauxXDRV.AddMeasureLine

function fauxXDRV.GetPlayerNoteColor(column)
  if column < 0 or column > 7 then
    error('column index (' .. column .. ') out of range (0..7)', 2)
  end
  return {({
    xdrvColors.scheme.colors.LeftGear,
    xdrvColors.scheme.colors.Column1,
    xdrvColors.scheme.colors.Column2,
    xdrvColors.scheme.colors.Column3,
    xdrvColors.scheme.colors.Column4,
    xdrvColors.scheme.colors.Column5,
    xdrvColors.scheme.colors.Column6,
    xdrvColors.scheme.colors.RightGear,
  })[column - 1]:unpack()}
end
fauxXDRV.get_player_note_color = fauxXDRV.GetPlayerNoteColor

function fauxXDRV.GetPlayerNoteColorChannel(column, index)
  return fauxXDRV.GetPlayerNoteColor(column)[index - 1]
end
fauxXDRV.get_player_note_color_channel = fauxXDRV.GetPlayerNoteColorChannel

function fauxXDRV.GetPlayerNoteColorRed(column) return fauxXDRV.GetPlayerNoteColor(column)[1] end
fauxXDRV.get_player_note_color_red = fauxXDRV.GetPlayerNoteColorRed
function fauxXDRV.GetPlayerNoteColorGreen(column) return fauxXDRV.GetPlayerNoteColor(column)[2] end
fauxXDRV.get_player_note_color_green = fauxXDRV.GetPlayerNoteColorGreen
function fauxXDRV.GetPlayerNoteColorBlue(column) return fauxXDRV.GetPlayerNoteColor(column)[3] end
fauxXDRV.get_player_note_color_blue = fauxXDRV.GetPlayerNoteColorBlue
function fauxXDRV.GetPlayerNoteColorAlpha(column) return fauxXDRV.GetPlayerNoteColor(column)[4] end
fauxXDRV.get_player_note_color_alpha = fauxXDRV.GetPlayerNoteColorAlpha

function fauxXDRV.GetPlayerScrollSpeed()
  return math.max(config.config.scrollSpeed, 0.5)
end
fauxXDRV.get_player_scroll_speed = fauxXDRV.GetPlayerScrollSpeed

function fauxXDRV.Set(...)
  if type(arg[1]) == 'number' or type(arg[1]) == 'table' then
    local note, modName, value, beatOrTime, timingValue = ...
    warn('Note mods unsupported')
    return
  end
  local modName, value, beatOrTime, timingValue = ...

  checkArg(modName, 1, 'string')
  checkArg(value, 2, 'number')
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    warn('beatOrTime arg is neither \'beat\' nor \'time\', but \'' .. tostring(beatOrTime) .. '\'')
  end
  checkArg(timingValue, 4, 'number')

  local time = beatOrTime == 'time'

  table.insert(eases, {
    beat = (not time) and timingValue or nil,
    time = time and timingValue or nil,
    ease = {
      target = 'mod_' .. modName,
      value = value,
      dur = 0,
      time = time,
      ease = easeFunctions.Instant,
    },
  })
end
fauxXDRV.set = fauxXDRV.Set
fauxXDRV.Mod = fauxXDRV.Set
fauxXDRV.mod = fauxXDRV.Mod

function fauxXDRV.Ease(...)
  if type(arg[1]) == 'number' or type(arg[1]) == 'table' then
    local note, modName, startValue, endValue, beatOrTime, startTime, lenOrEnd, endTime, easeName = ...
    warn('Note mods unsupported')
    return
  end
  local modName, startValue, endValue, beatOrTime, startTime, lenOrEnd, endTime, easeName = ...
  checkArg(modName, 1, 'string')
  checkArg(startValue, 2, 'number')
  checkArg(endValue, 3, 'number')
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    warn('beatOrTime arg is neither \'beat\' nor \'time\', but \'' .. tostring(beatOrTime) .. '\'')
  end
  checkArg(startTime, 5, 'number')
  if not (lenOrEnd == 'len' or lenOrEnd == 'end') then
    warn('lenOrEnd arg is neither \'len\' nor \'end\', but \'' .. tostring(lenOrEnd) .. '\'')
  end
  checkArg(endTime, 7, 'number')
  checkArg(easeName, 8, 'string')

  local time = beatOrTime == 'time'
  local ends = lenOrEnd == 'end'

  if ends and endTime < startTime then
    warn('ease ends before it starts (' .. endTime .. ' < ' .. startTime .. ')')
    return
  end

  local ease = easeFunctionsLower[string.lower(easeName)]
  if not ease then
    warn('no such ease ' .. easeName)
  end

  table.insert(eases, {
    beat = (not time) and startTime or nil,
    time = time and startTime or nil,
    ease = {
      target = 'mod_' .. modName,
      startValue = startValue,
      value = endValue,
      dur = ends and (endTime - startTime) or endTime,
      time = time,
      ease = ease,
    },
  })
end
fauxXDRV.ease = fauxXDRV.Ease

function fauxXDRV.Load(filename)
  if not chart.loadedScripts[filename] then
    local res = chart.tryLoadScript(filename)
    if not res then
      error('Failed loading file ' .. filename, 2)
    end
  end

  local f, err = loadstring(chart.loadedScripts[filename], filename)
  if not f then
    error(err, 2)
  end
  local env = getfenv(2)
  setfenv(f, env)
  f()
end
fauxXDRV.load = fauxXDRV.Load

-- just to fix errors for unsupported stuff

fauxXDRV.GetNoteData = function() return {} end
fauxXDRV.get_note_data = fauxXDRV.GetNoteData
fauxXDRV.GetNoteDataInBeatRange = function() return {} end
fauxXDRV.get_note_data_in_beat_range = fauxXDRV.GetNoteDataInBeatRange
fauxXDRV.GetNoteDataInTimeRange = function() return {} end
fauxXDRV.get_note_data_in_time_range = fauxXDRV.GetNoteDataInTimeRange
fauxXDRV.GetNoteDataOfType = function() return {} end
fauxXDRV.get_note_data_of_type = fauxXDRV.GetNoteDataOfType
fauxXDRV.GetNoteDataOfTypeInTimeRange = function() return {} end
fauxXDRV.get_note_data_of_type_in_time_range = fauxXDRV.GetNoteDataOfTypeInTimeRange
fauxXDRV.GetNoteDataOfTypeInDisplayBeatRange = function() return {} end
fauxXDRV.get_note_data_of_type_in_display_beat_range = fauxXDRV.GetNoteDataOfTypeInDisplayBeatRange
fauxXDRV.GetNoteDataOfTypeInBeatRange = function() return {} end
fauxXDRV.get_note_data_of_type_in_beat_range = fauxXDRV.GetNoteDataOfTypeInBeatRange

-- metatable funcs get applied when passing into script

function fauxXDRV:__index(idx)
  return rawget(self, idx) or function()
    warn(idx .. ': Unimplemented')
    return 0
  end
end

local safeString = deepcopy(string)
safeString.dump = nil

local safeEnv = {
  coroutine = deepcopy(coroutine),
  assert = assert,
  tostring = tostring,
  tonumber = tonumber,
  rawget = rawget,
  xpcall = xpcall,
  ipairs = ipairs,
  print = print,
  pcall = pcall,
  pairs = pairs,
  error = error,
  rawequal = rawequal,
  --loadstring = loadstring,
  rawset = rawset,
  unpack = unpack,
  table = deepcopy(table),
  next = next,
  math = deepcopy(math),
  load = load,
  select = select,
  string = safeString,
  type = type,
  getmetatable = getmetatable,
  setmetatable = setmetatable
}

local function getEnv()
  local xdrv = deepcopy(fauxXDRV)

  local env = merge(safeEnv, {
    xdrv = setmetatable(xdrv, xdrv),
    print = function(...)
      local args = {...}
      local strings = {}
      for k, v in pairs(args) do
        strings[k] = tostring(v)
      end
      local info = debug.getinfo(2, 'lS')
      logs.log(info.short_src .. ':' .. info.currentline .. ': ' .. table.concat(strings, ' '))
    end
  })

  return env
end

function self.bakeEases()
  eases = {}
  activeEases = {}
  inactiveEases = {}
  valuesBuffer = {}
  measureLines = {}
  lastBeat = 9e9
  if chart.loadedScripts[chart.metadata.modfilePath] then
    local path = chart.metadata.modfilePath -- must be an upvalue
    local traceback = debug.traceback -- also must be an upvalue
    local trace, err
    sandbox.run(function()
      xpcall(function()
        fauxXDRV.Load(path)
      end, function(res)
        err = res
        trace = traceback()
      end)
    end, { env = getEnv(), chunkname = chart.metadata.modfilePath })

    if err then
      local _, _, name, line, message = string.find(err, '%[string "(.-)"%]:(%d+): (.+)')

      if name and line and message then
        logs.warn(name .. ':' .. line .. ': ' .. message)
        if trace then
          local skip = 2
          for s in string.gmatch(trace, '[^\r\n]+') do
            if skip > 0 then
              skip = skip - 1
            else
              if not string.find(s, 'src/preview%.lua: in function \'[Ll]oad\'') then
                if string.find(s, 'src/preview%.lua') then break end
                logs.warn(string.gsub(s, '%[string "(.-)"%]:(%d+)', '%1:%2'))
              end
            end
          end
        end

        if DEBUG_SCRIPTS then
          local filename = 'debug_' .. name
          love.filesystem.write(filename, chart.loadedScripts[name])
          os.execute('code --goto "' .. love.filesystem.getRealDirectory(filename) .. '/' .. filename .. ':' .. line .. '"')
        end
      else
        logs.warn('Error evaluating script: ' .. err)
      end

      -- reset to prevent stupid things from happening
      eases = {}
      measureLines = {}
    end
  end
  for _, thing in ipairs(chart.chart) do
    if thing.event and easeConverters[thing.event.name] then
      local args = StringArgSet.new()
      args:push(unpack(thing.event.args))
      local ok, res = pcall(addEvent, thing.beat, nil, thing.event.name, args)
      if not ok then
        warn('Error adding event: ' .. res, 'Beat ' .. thing.beat)
        logs.logFile(pretty(thing[getThingType(thing)]))
      end
    end
  end
  sort.stable_sort(eases, easeSort)

  knownModNames = {}
  for _, ease in ipairs(eases) do
    local target = aliases[ease.ease.target] or ease.ease.target
    knownModNames[target] = true
  end
end

function self.getKnownModNames()
  return knownModNames
end

return self