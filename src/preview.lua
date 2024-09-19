local config = require 'src.config'
local easeFunctions = require 'lib.ease'
local conductor     = require 'src.conductor'
local xdrv          = require 'lib.xdrv'

local easeFunctionsLower = {}
for k, v in pairs(easeFunctions) do easeFunctionsLower[string.lower(k)] = v end

local self = {}

function self.getScrollSpeed(beat)
  if not config.config.previewMode then return 1 end
  if not chart.chart then return 1 end

  local speed = 1
  -- update i don't think scroll events work like this
  --[[
  for _, thing in ipairs(chart.chart) do
    if thing.beat > beat then
      return speed
    end
    if thing.scroll then
      speed = thing.scroll
    end
  end
  ]]
  return speed
end

---@alias Ease { target: string, value: number, dur: number, time: boolean, ease: fun(a: number): number }
---@alias TimedEase { beat: number?, time: number?, ease: Ease }

---@type TimedEase[]
local eases = {}

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
}

---@param type string
---@param beat number?
function self.getEasedValue(type, beat)
  beat = beat or conductor.beat
  local time = conductor.timeAtBeat(beat)

  local value = defaultValues[type] or 0

  for _, ease in ipairs(eases) do
    if (ease.beat and ease.beat > beat) or (ease.time and ease.time > time) then break end

    if ease.ease.target == type then
      local a = ((ease.time and time or beat) - (ease.time and ease.time or ease.beat)) / ease.ease.dur
      value = mix(value, ease.ease.value, ease.ease.ease(clamp(a, 0, 1)))
    end
  end

  return value
end

function self.bakeEases()
  eases = {}
  for _, thing in ipairs(chart.chart) do
    if thing.event and easeConverters[thing.event.name] then
      local ease = easeConverters[thing.event.name](unpack(thing.event.args))
      table.insert(eases, {
        beat = (not ease.time) and thing.beat or nil,
        time = (ease.time) and conductor.timeAtBeat(thing.beat) or nil,
        ease = ease,
      })
    end
  end
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

return self