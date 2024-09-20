local config = require 'src.config'
local easeFunctions = require 'lib.ease'
local conductor     = require 'src.conductor'
local xdrv          = require 'lib.xdrv'
local logs          = require 'src.logs'
local xdrvColors    = require 'src.xdrvcolors'
local sort          = require 'lib.sort'

local easeFunctionsLower = {}
for k, v in pairs(easeFunctions) do easeFunctionsLower[string.lower(k)] = v end

local self = {}

function self.getScrollSpeed(beat)
  if not config.config.previewMode then return 1 end
  if not chart.chart then return 1 end

  local speed = self.getModValue('speed')
  return speed
end

---@alias Ease { target: string, startValue: number?, value: number, dur: number, time: boolean, ease: fun(a: number): number }
---@alias TimedEase { beat: number?, time: number?, ease: Ease }

---@type TimedEase[]
local eases = {}
local knownModNames = {}

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
  return function(alpha) return {
    target = target,
    value = alpha,
    dur = 0,
    time = false,
    ease = easeFunctions.Instant,
  } end
end
local function genericEase(target)
  return function(alpha, dur, time, ease) return {
    target = target,
    value = alpha,
    dur = dur,
    time = time or false,
    ease = easeFunctionsLower[string.lower(ease or 'Linear')],
  } end
end

-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/global.md
-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/tunnel.md
-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/backgrounds/city.md
---@type table<string, fun(...): Ease>
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
}

local aliases = {
  mod_camera_move_x = 'mod_camera_position_x',
  mod_camera_move_y = 'mod_camera_position_y',
  mod_camera_move_z = 'mod_camera_position_z',
  mod_camera_rotate_x = 'mod_camera_rotation_x',
  mod_camera_rotate_y = 'mod_camera_rotation_y',
  mod_camera_rotate_z = 'mod_camera_rotation_z',
  mod_camera_field_of_vision = 'mod_camera_fov',
}

---@param type string
---@param beat number?
function self.getEasedValue(type, beat)
  if not config.config.previewMode then
    return defaultValues[type] or 0
  end

  beat = beat or conductor.beat
  local time = conductor.timeAtBeat(beat)

  local value = defaultValues[type] or 0

  for _, ease in ipairs(eases) do
    if (ease.beat and ease.beat > beat) or (ease.time and ease.time > time) then break end

    local target = aliases[ease.ease.target] or ease.ease.target
    if target == type then
      local a = ((ease.time and time or beat) - (ease.time and ease.time or ease.beat)) / ease.ease.dur
      value = mix(ease.ease.startValue or value, ease.ease.value, ease.ease.ease(clamp(a, 0, 1)))
    end
  end

  return value
end
function self.getModValue(type)
  return self.getEasedValue('mod_' .. type)
end

local function addEvent(beat, time, name, args)
  local ease = easeConverters[name](unpack(args))

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
end

local fauxXDRV = {}

function fauxXDRV.__checkArg(value, index, typee)
  if type(value) ~= typee then
    error('expected arg #' .. index .. ' to be ' .. typee .. ', got ' .. type(value), 3)
  end
end
function fauxXDRV.__warn(msg)
  local info = debug.getinfo(3, 'lS')
  logs.log('Warning: ' .. info.short_src .. ':' .. info.currentline .. ': ' .. msg)
end

function fauxXDRV.RunEvent(eventName, beatOrTime, timingValue, ...)
  fauxXDRV.__checkArg(eventName, 1, 'string')
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    fauxXDRV.__warn('beatOrTime arg is neither \'beat\' nor \'time\'')
  end
  fauxXDRV.__checkArg(timingValue, 3, 'number')

  local time = beatOrTime == 'time'

  addEvent(
    (not time) and timingValue or nil,
    time and timingValue or nil,
    eventName,
    ...
  )
end
fauxXDRV.run_event = fauxXDRV.RunEvent

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
  -- TODO
  return 1
end
fauxXDRV.get_player_scroll_speed = fauxXDRV.GetPlayerScrollSpeed

function fauxXDRV.Set(modName, value, beatOrTime, timingValue)
  fauxXDRV.__checkArg(modName, 1, 'string')
  fauxXDRV.__checkArg(value, 2, 'number')
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    fauxXDRV.__warn('beatOrTime arg is neither \'beat\' nor \'time\'')
  end
  fauxXDRV.__checkArg(timingValue, 4, 'number')

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

function fauxXDRV.Ease(modName, startValue, endValue, beatOrTime, startTime, lenOrEnd, endTime, easeName)
  fauxXDRV.__checkArg(modName, 1, 'string')
  fauxXDRV.__checkArg(startValue, 2, 'number')
  fauxXDRV.__checkArg(endValue, 3, 'number')
  if not (beatOrTime == 'beat' or beatOrTime == 'time') then
    fauxXDRV.__warn('beatOrTime arg is neither \'beat\' nor \'time\'')
  end
  fauxXDRV.__checkArg(startTime, 5, 'number')
  if not (lenOrEnd == 'len' or lenOrEnd == 'end') then
    fauxXDRV.__warn('lenOrEnd arg is neither \'len\' nor \'end\'')
  end
  fauxXDRV.__checkArg(endTime, 7, 'number')
  fauxXDRV.__checkArg(easeName, 8, 'string')

  local time = beatOrTime == 'time'
  local ends = lenOrEnd == 'end'

  if ends and endTime < startTime then
    fauxXDRV.__warn('ease ends before it starts (' .. endTime .. ' < ' .. startTime .. ')')
    return
  end

  local ease = easeFunctionsLower[string.lower(easeName)]
  if not ease then
    fauxXDRV.__warn('no such ease ' .. easeName)
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

-- metatable funcs get applied when passing into script

function fauxXDRV:__index(idx)
  return rawget(self, idx) or function()
    fauxXDRV.__warn(idx .. ': Unimplemented')
    return 0
  end
end

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
  loadstring = loadstring,
  rawset = rawset,
  unpack = unpack,
  table = deepcopy(table),
  next = next,
  math = deepcopy(math),
  load = load,
  select = select,
  string = deepcopy(string),
  type = type,
  getmetatable = getmetatable,
  setmetatable = setmetatable
}

function self.bakeEases()
  eases = {}
  if chart.loadedScript then
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
    env._G = env
    env._ENV = env

    setfenv(chart.loadedScript, env)

    local success, res = pcall(chart.loadedScript)
    if not success then
      logs.log('Error evaluating script: ' .. res)
      -- reset to prevent stupid things from happening
      eases = {}
    end
  end
  for _, thing in ipairs(chart.chart) do
    if thing.event and easeConverters[thing.event.name] then
      addEvent(thing.beat, nil, thing.event.name, thing.event.args)
    end
  end
  sort.stable_sort(eases, function(a, b)
    if a.beat and b.beat then return a.beat < b.beat end
    if a.time and b.time then return a.time < b.time end
    if a.beat then
      return a.beat < conductor.beatAtTime(b.time)
    end
    if a.time then
      return conductor.beatAtTime(a.time) < b.beat
    end
    error('What? huh? is anyone there?')
  end)

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