local M = {}

local logs = require 'src.logs'
local config = require 'src.config'
local waveform = require 'src.waveform'

local audio = require 'src.audio'

local beatTickSFX = audio.makeSoundPool('assets/sfx/tick.wav')
local noteTickSFX = audio.makeSoundPool('assets/sfx/clap.wav')

---@type love.Source?
local song

M.offset = -0.007
M.initialBPM = 120
M.bpms = { { 0, 120 } }
M.stops = {}
M.timeSignatures = {}
M.fileData = nil
M.measures = {}

M.time = 0
M.playing = false

M.lastSec = 0

function M.reset()
  M.time = 0
  M.playing = false
end

function M.loadSong(songPath)
  M.fileData = nil
  local file, err = io.open(songPath, 'rb')
  if file then
    local data = file:read('*a')
    if song then
      song:stop()
      song:release()
    end
    if data then
      local fileData = love.filesystem.newFileData(data, chart.metadata.musicAudio)
      waveform.clear()
      if config.config.waveform then
        waveform.init(fileData)
      end
      M.fileData = fileData
      song = love.audio.newSource(fileData, 'static')
    end
    file:close()
  else
    logs.warn(err)
  end
end

---@param chart XDRVChart
function M.loadTimings(chart)
  M.initialBPM = chart.metadata.chartBPM
  --M.bpms = { { 0, M.initialBPM } }
  M.bpms = {}
  M.measures = {}
  M.timeSignatures = {}
  M.stops = {}
  for _, thing in ipairs(chart.chart) do
    if thing.bpm then
      table.insert(M.bpms, { thing.beat, thing.bpm })
    elseif thing.timeSignature then
      table.insert(M.timeSignatures, { thing.beat, thing.timeSignature })
    elseif thing.stop or thing.stopSeconds or thing.warp then
      local duration = thing.stop or thing.stopSeconds or thing.warp
      if thing.warp then duration = -duration end
      local seconds = thing.stopSeconds ~= nil
      table.insert(M.stops, { thing.beat, duration, seconds })
    end
  end
  -- this really should only be a failsafe, as a similar check is done on the
  -- chart loading level
  if not M.bpms[1] or M.bpms[1][1] > 0 then
    table.insert(M.bpms, 1, { 0, M.initialBPM })
  end
  M.makeMeasureLines()
end

---@param chart XDRVChart
function M.loadFromChart(chart, dir)
  M.offset = chart.metadata.musicOffset
  M.loadSong(dir .. chart.metadata.musicAudio)

  M.loadTimings(chart)
  M.lastSec = M.timeAtBeat(chart.chart[#chart.chart].beat)
end

function M.makeMeasureLines()
  -- borrowed from tari

  M.measures = {}

  local timeSigBeat = 4
  local timeSigSubdiv = 4

  local nextMeasure = 0
  local totalBeats = math.ceil(M.beatAtTime(M.getDuration() + M.offset))

  while nextMeasure < totalBeats do
    local sig = M.getTimeSignatureAtBeat(nextMeasure)
    timeSigBeat, timeSigSubdiv = sig[1], sig[2]

    if timeSigBeat <= 0 or timeSigSubdiv <= 0 then -- what
      break
    end

    table.insert(M.measures, nextMeasure)

    nextMeasure = nextMeasure + timeSigBeat / (timeSigSubdiv / 4)
  end
end

function M.secondsToBeats(s, bpm)
  return s * ((bpm or M.getBPM()) / 60)
end
function M.beatsToSeconds(b, bpm)
  return (b * 60) / (bpm or M.getBPM())
end

function M.getBPMAtBeat(b)
  local bpm = M.initialBPM
  for _, change in ipairs(M.bpms) do
    if b >= change[1] then
      bpm = change[2]
    else
      break
    end
  end
  return bpm
end
function M.getBPM()
  return M.getBPMAtBeat(M.beat)
end

-- kindly borrowed from taro
function M.beatAtTime(t)
  for i, segment in ipairs(M.bpms) do
    local startBeat = segment[1]
    local bpm = segment[2]

    local isFirstBPM = i == 1
    local isLastBPM = i == #M.bpms

    local startBeatNextSegment = 9e99
    if not isLastBPM then startBeatNextSegment = M.bpms[i + 1][1] end

    for _, stop in ipairs(M.stops) do
      local stopStartBeat = stop[1]
      local stopDuration = stop[2]
      local stopIsSeconds = stop[3]
      if not stopIsSeconds then
        -- stop duration must be in seconds
        stopDuration = M.beatsToSeconds(stopDuration, bpm)
      end

      if not isLastBPM and startBeat > startBeatNextSegment then break end
      if not (not isFirstBPM and startBeat >= stopStartBeat) then
        -- this freeze lies within this BPMSegment
        local freezeBeat = stopStartBeat - startBeat
        local freezeSecond = M.beatsToSeconds(freezeBeat, bpm)
        if freezeSecond >= t then break end

        -- the freeze segment is <= current time
        t = t - stopDuration

        if freezeSecond >= t then
          -- The time lies within the stop. Song is currently stopped
          return stopStartBeat
        end
      end
    end

    local beatsThisSegment = startBeatNextSegment - startBeat
    local secondsThisSegment = M.beatsToSeconds(beatsThisSegment, bpm)

    if isLastBPM or t <= secondsThisSegment then
      -- this segment is the current segment
      return startBeat + M.secondsToBeats(t, bpm)
    end

    -- this segment is NOT the current segment
    t = t - secondsThisSegment
  end

  -- should never get here
  local lastBPM = M.bpms[#M.bpms]
  return lastBPM[1] + M.secondsToBeats(t, lastBPM)
end

function M.timeAtBeat(beat)
  local tempElapsed = 0

  for _, stop in ipairs(M.stops) do
    local stopStartBeat = stop[1]
    local stopDuration = stop[2]
    local stopIsSeconds = stop[3]
    -- The exact beat of a stop comes before the stop, not after, so use >=, not >.
    if stopStartBeat >= beat then break end
    if not stopIsSeconds then
      -- stop duration must be in seconds
      stopDuration = M.beatsToSeconds(stopDuration, M.getBPMAtBeat(stopStartBeat))
    end
    tempElapsed = tempElapsed + stopDuration
  end

  for i, segment in ipairs(M.bpms) do
    local startBeat = segment[1]
    local bpm = segment[2]

    if i == #M.bpms then
      tempElapsed = tempElapsed + M.beatsToSeconds(beat, bpm)
    else
      local startBeatThisSegment = startBeat
      local startBeatNextSegment = M.bpms[i + 1][1]
      local beatsThisSegment = math.min(startBeatNextSegment - startBeatThisSegment, beat)
      tempElapsed = tempElapsed + M.beatsToSeconds(beatsThisSegment, bpm) -- count time based on how many beats we spent at each bpm
      beat = beat - beatsThisSegment
    end

    if beat <= 0 then return tempElapsed end
  end

  return tempElapsed
end

function M.getTimeSignatureAtBeat(beat)
  local sig = { 4, 4 }
  for _, change in ipairs(M.timeSignatures) do
    if change[1] > beat then
      return sig
    end
    sig = change[2]
  end
  return sig
end
function M.getTimeSignature()
  return M.getTimeSignatureAtBeat(M.beat)
end

local chartStates = {}

function M.initStates()
  if not chart.loaded then return end
  for i, thing in ipairs(chart.chart) do
    local state = { hit = thing.beat < M.beat }
    if thing.gearShift then
      state.hitEnd = (thing.beat + thing.gearShift.length) < M.beat
    end
    chartStates[i] = state
  end
  for i = 1, 6 do
    laneRelease(i)
  end
end

function M.play()
  if not song then return end
  M.initStates()
  M.playing = true
end
function M.pause()
  if not song then return end
  M.playing = false
end

function M.getDuration()
  if not song then return M.lastSec end
  return song:getDuration()
end

local function updateSongPos()
  M.time = math.max(M.time, 0)
  M.time = math.min(M.time, M.getDuration())
  if not song then
    M.playing = false
    --M.time = 0
    M.updateBeat()
    return
  end
  local position = M.time - M.offset
  local min = 0
  local max = song:getDuration()
  if position >= min and position < max then
    song:seek(position)
    if M.playing and not song:isPlaying() then
      song:play()
    elseif not M.playing and song:isPlaying() then
      song:pause()
    end
  else
    song:stop()
  end
  M.updateBeat()
end

function M.seek(s)
  M.time = s
  updateSongPos()
end
function M.seekDelta(s)
  M.time = M.time + s
  updateSongPos()
end
function M.seekBeats(b)
  M.time = M.timeAtBeat(b)
  updateSongPos()
end
function M.isPlaying()
  return M.playing
end

function M.updateBeat()
  M.beat = M.beatAtTime(M.time)
end

---@param thing XDRVThing
local function onInputPress(thing)
  if thing.note then
    laneHit(thing.note.column)
  end
end
---@param thing XDRVThing
local function onInputRelease(thing)
  if thing.note then
    laneRelease(thing.note.column)
  end
end

local lastT = 0

function M.update(dt)
  if M.isPlaying() then
    M.time = M.time + dt * config.config.musicRate
    if config.config.beatTick and math.floor(M.beatAtTime(M.time)) > math.floor(M.beatAtTime(lastT)) then
      beatTickSFX:play(0.5)
    end
    lastT = M.time

    for i, thing in ipairs(chart.chart) do
      if (thing.note or thing.gearShift) and thing.beat < M.beat and not chartStates[i].hit then
        chartStates[i].hit = true
        onInputPress(thing)
        if thing.note and not thing.note.length then
          onInputRelease(thing)
        end
        if config.config.noteTick then
          noteTickSFX:play(0.75)
        end
      end
      if ((thing.note and thing.note.length) or thing.gearShift) and not chartStates[i].hitEnd then
        local length = 0
        if thing.note then length = thing.note.length end
        if thing.gearShift then length = thing.gearShift.length end
        if (thing.beat + length) < M.beat then
          chartStates[i].hitEnd = true
          onInputRelease(thing)
          if thing.gearShift and config.config.noteTick then
            noteTickSFX:play(0.75)
          end
        end
      end
    end
  end
  M.updateBeat()
  if song then
    if M.playing ~= song:isPlaying() then
      updateSongPos()
    end

    song:setVolume(audio.normalizeVolume(config.config.volume))
    song:setPitch(config.config.musicRate)
  end
end

return M