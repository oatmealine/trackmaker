local M = {}

---@type love.Source?
local song

M.offset = -0.007
M.bpm = 120

---@param chart XDRVChart
function M.loadFromChart(chart, dir)
  M.offset = tonumber(chart.metadata.MUSIC_OFFSET) or 0
  local songPath = dir .. chart.metadata.MUSIC_AUDIO
  local file = io.open(songPath, 'rb')
  if file then
    local data = file:read('*a')
    song = love.audio.newSource(love.filesystem.newFileData(data, chart.metadata.MUSIC_AUDIO), 'static')
    file:close()
  end
  M.bpm = tonumber(chart.metadata.CHART_BPM) or 120
end

function M.getSeconds()
  if not song then return 0 end
  return song:tell() + M.offset
end
function M.getBeat()
  return M.timeToBeats(M.getSeconds())
end

function M.secondsToBeats(s, bpm)
  return s * ((bpm or M.getBPM()) / 60)
end
function M.beatsToSeconds(b, bpm)
  return (b * 60) / (bpm or M.getBPM())
end

function M.getBPM()
  --return M.getBPMAtBeat(M.getBeat())
  return M.bpm
end

-- kindly borrowed from taro
function M.timeToBeats(t)
  --[[local bpms = self.getTrack().bpms
  for i, segment in ipairs(bpms) do
    local startBeat = segment[1]
    local bpm = segment[2]

    local isFirstBPM = i == 1
    local isLastBPM = i == #bpms

    local startBeatNextSegment = 9e99
    if not isLastBPM then startBeatNextSegment = bpms[i + 1][1] end

    local beatsThisSegment = startBeatNextSegment - startBeat
    local secondsThisSegment = self.beatsToSeconds(beatsThisSegment, bpm)

    if isLastBPM or t <= secondsThisSegment then
      -- this segment is the current segment
      return startBeat + self.secondsToBeats(t, bpm)
    end

    -- this segment is NOT the current segment
    t = t - secondsThisSegment
  end]]

  return M.secondsToBeats(t)
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