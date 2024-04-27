local M = {}

---@type love.Source?
local song

M.offset = -0.007
M.initialBPM = 120
M.bpms = { { 0, 120 } }
M.stops = {}

M.time = 0
M.playing = false

function M.reset()
  M.time = 0
  M.playing = false
end

---@param chart XDRVChart
function M.loadFromChart(chart, dir)
  M.offset = chart.metadata.musicOffset
  local songPath = dir .. chart.metadata.musicAudio
  local file = io.open(songPath, 'rb')
  if file then
    local data = file:read('*a')
    if song then song:release() end
    song = love.audio.newSource(love.filesystem.newFileData(data, chart.metadata.musicAudio), 'static')
    file:close()
  end

  M.initialBPM = chart.metadata.chartBPM
  M.bpms = { { 0, M.initialBPM } }
  for _, event in ipairs(chart.chart) do
    if event.bpm then
      table.insert(M.bpms, { event.beat, event.bpm })
    elseif event.stop or event.stopSeconds or event.warp then
      local duration = event.stop or event.stopSeconds or event.warp
      if event.warp then duration = -duration end
      local seconds = event.stopSeconds ~= nil
      table.insert(M.stops, { event.beat, duration, seconds })
    end
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

function M.timeAtBeat(b)
  -- TODO
  return M.beatsToSeconds(b, M.getBPM())
end

function M.play()
  M.playing = true
end
function M.pause()
  M.playing = false
end

local function updateSongPos()
  if not song then return end
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

function M.update(dt)
  M.beat = M.beatAtTime(M.time)
  if M.isPlaying() then
    M.time = M.time + dt
  end
  if song and M.playing ~= song:isPlaying() then
    updateSongPos()
  end
end

return M