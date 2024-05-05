local M = {}

local logs = require 'src.logs'
local config = require 'src.config'

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

M.time = 0
M.playing = false

function M.reset()
  M.time = 0
  M.playing = false
end

function M.loadSong(songPath)
  local file, err = io.open(songPath, 'rb')
  if file then
    local data = file:read('*a')
    if song then song:release() end
    if data then
      song = love.audio.newSource(love.filesystem.newFileData(data, chart.metadata.musicAudio), 'static')
    end
    file:close()
  else
    logs.log(err)
  end
end

---@param chart XDRVChart
function M.loadFromChart(chart, dir)
  M.offset = chart.metadata.musicOffset
  M.loadSong(dir .. chart.metadata.musicAudio)

  M.initialBPM = chart.metadata.chartBPM
  M.bpms = { { 0, M.initialBPM } }
  for _, event in ipairs(chart.chart) do
    if event.bpm then
      table.insert(M.bpms, { event.beat, event.bpm })
    elseif event.timeSignature then
      table.insert(M.timeSignatures, { event.beat, event.timeSignature })
    elseif event.stop or event.stopSeconds or event.warp then
      local duration = event.stop or event.stopSeconds or event.warp
      if event.warp then duration = -duration end
      local seconds = event.stopSeconds ~= nil
      table.insert(M.stops, { event.beat, duration, seconds })
    end
  end

  print(pretty(M.timeSignatures))
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

function M.timeAtBeat(b)
  -- TODO
  return M.beatsToSeconds(b, M.getBPM())
end

function M.getTimeSignatureAtBeat(beat)
  local sig = { 4, 4 }
  for _, change in ipairs(M.timeSignatures) do
    if change.beat > beat then
      return sig
    end
    sig = change.timeSignature
  end
  return sig
end
function M.getTimeSignature()
  return M.getTimeSignatureAtBeat(M.beat)
end

function M.getMeasure(beat)
  local m = 0
  local b = beat
  local sig = { 4, 4 }
  local lastBeat = 0
  for _, change in ipairs(M.timeSignatures) do
    if beat < change[1] then
      m = m + b / sig[1]
      return m
    else
      sig = change[2]
      b = b - (change[1] - lastBeat)
      m = m + (change[1] - lastBeat) / sig[1]
      lastBeat = change[1]
    end
  end
  m = m + b / sig[1]
  return m
end

local eventStates = {}

function M.initStates()
  for i, event in ipairs(chart.chart) do
    local state = { hit = event.beat < M.beat }
    if event.gearShift then
      state.hitEnd = (event.beat + event.gearShift.length) < M.beat
    end
    eventStates[i] = state
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
  if not song then return 0 end
  return song:getDuration()
end

local function updateSongPos()
  M.time = math.max(M.time, 0)
  M.time = math.min(M.time, M.getDuration())
  if not song then
    M.playing = false
    M.time = 0
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

local lastT = 0

function M.update(dt)
  if M.isPlaying() then
    M.time = M.time + dt * config.config.musicRate
    if config.config.beatTick and math.floor(M.beatAtTime(M.time)) > math.floor(M.beatAtTime(lastT)) then
      beatTickSFX:play(0.5)
    end
    lastT = M.time

    for i, event in ipairs(chart.chart) do
      if event.beat < M.beat and not eventStates[i].hit then
        eventStates[i].hit = true
        if config.config.noteTick then
          noteTickSFX:play(0.75)
        end
      end
      if event.gearShift and (event.beat + event.gearShift.length) < M.beat and not eventStates[i].hitEnd then
        eventStates[i].hitEnd = true
        if config.config.noteTick then
          noteTickSFX:play(0.75)
        end
      end
    end
  end
  M.updateBeat()
  if song then
    if M.playing ~= song:isPlaying() then
      updateSongPos()
    end

    -- tuning the volume towards humans' logarithmically scaled hearing
    -- technically not precise but it's fast and easy to remember
    local tunedVolume = config.config.volume * config.config.volume
    song:setVolume(tunedVolume)
    song:setPitch(config.config.musicRate)
  end
end

return M