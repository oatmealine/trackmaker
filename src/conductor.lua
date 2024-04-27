local M = {}

---@type love.Source?
local song

M.offset = -0.007
M.initialBPM = 120
M.bpms = {}
M.stops = {}

---@param chart XDRVChart
function M.loadFromChart(chart, dir)
  M.offset = chart.metadata.musicOffset
  local songPath = dir .. chart.metadata.musicAudio
  local file = io.open(songPath, 'rb')
  if file then
    local data = file:read('*a')
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

function M.getSeconds()
  if not song then return 0 end
  return song:tell() + M.offset
end
function M.getBeat()
  return M.beatAtTime(M.getSeconds())
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
  return M.getBPMAtBeat(M.getBeat())
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

function M.timeAtBeat(t)
end

function M.play()
  if not song then return end
  song:play()
end
function M.pause()
  if not song then return end
  song:pause()
end
function M.seek(s)
  if not song then return end
  song:seek(math.max(s - M.offset, 0))
end
function M.seekDelta(s)
  if not song then return end
  song:seek(math.max(song:tell() + s, 0))
end
function M.isPlaying()
  if not song then return false end
  return song:isPlaying()
end

function M.update(dt)
  M.beat = M.getBeat()
end

return M