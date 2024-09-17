local logs   = require 'src.logs'
local audio  = require 'src.audio'
local config = require 'src.config'
local self = {}

---@type love.Decoder
self.decoder = nil
---@type table<number, table<number, number>>
self.samples = {}

local BUFFER_SIZE = 4096

local MESH_SEGMENT_SIZE = 1 -- seconds; different on different LODs
local BASE_SAMPLE_RATE = 128 -- vertices per second on base zoom

local function getSampleRate()
  return config.config.doubleResWaveform and (BASE_SAMPLE_RATE * 2) or BASE_SAMPLE_RATE
end

function self.clear()
  self.decoder = nil
  self.samples = {}
  self.bake = nil
  self.status = nil
  self.progress = nil
end

---@param data love.FileData
function self.init(data)
  -- love2d typing mistake
  ---@diagnostic disable-next-line: param-type-mismatch
  self.decoder = love.sound.newDecoder(data, BUFFER_SIZE)

  if self.decoder:getDuration() == -1 then
    logs.log('waveform: couldn\'t figure out song duration')
    self.decoder = nil
    return
  end

  self.samples = {}

  self.bake = coroutine.create(self.bakeMeshes)

  self.status = 'Baking waveform...'
  self.progress = 0
end

local UPDATE_TIMER = 1/80

function self.update()
  if not self.bake then return end

  self.resumedAt = os.clock()
  local _, segments, segmentsTotal, samples, samplesTotal, finished = coroutine.resume(self.bake)
  self.totalHeight = #self.meshes * MESH_SEGMENT_SIZE
  self.status = string.format('Baking waveform... %d/%d segments', segments, segmentsTotal)
  self.progress = ((segments + (samples / samplesTotal)) / segmentsTotal)
  if finished then
    self.status = nil
    self.bake = nil
    self.samples = nil
    self.progress = nil
    collectgarbage('collect')
  end
  events.redraw()
end

local function sampleToSeconds(idx)
  return idx / self.decoder:getSampleRate()
end

local function secondsToSample(s)
  return s * self.decoder:getSampleRate()
end

local function tryFillSample(idx)
  if idx < 0 then return end
  local s = sampleToSeconds(idx)
  if s >= self.decoder:getDuration() then return end

  -- to prevent memory leaking
  self.samples = {}

  self.decoder:seek(s)
  local soundData = self.decoder:decode()

  for sample = 0, soundData:getSampleCount() - 1 do
    self.samples[idx + sample] = {}
    for channel = 1, self.decoder:getChannelCount() do
      self.samples[idx + sample][channel] = soundData:getSample(sample, channel)
    end
  end

  return self.samples[idx]
end

local function getSample(idx)
  return self.samples[idx] or tryFillSample(idx)
end

local function getSampleSum(from, to)
  local sum = {}
  for i = 1, self.decoder:getChannelCount() do
    sum[i] = 0
  end
  for smp = from, to do
    local sample = getSample(smp)
    if not sample then break end
    for i, v in ipairs(sample) do
      sum[i] = sum[i] + audio.inverseNormalizeVolume(math.abs(v)) / ((to + 1) - from)
    end
  end
  return sum
end

function self.bakeMeshes()
  self.meshes = {}
  local samplesPerSegment = math.floor(getSampleRate() * MESH_SEGMENT_SIZE)
  local totalSegments = math.ceil(self.decoder:getDuration() / MESH_SEGMENT_SIZE)
  for segment = 1, totalSegments do
    local second = (segment - 1) * MESH_SEGMENT_SIZE
    local meshes = {}
    for i = 1, self.decoder:getChannelCount() do
      meshes[i] = love.graphics.newMesh(samplesPerSegment * 2, 'strip', 'static')
    end
    for sample = 1, samplesPerSegment do
      local from = secondsToSample(second + ((sample - 1) / samplesPerSegment) * MESH_SEGMENT_SIZE)
      local to = secondsToSample(second + ((sample) / samplesPerSegment) * MESH_SEGMENT_SIZE) - 1
      local sum = getSampleSum(from, to)
      -- temporarily just read first channel

      for channel, a in ipairs(sum) do
        local y = (sample - 1) / (samplesPerSegment - 1)
        local width = a

        meshes[channel]:setVertices({ { 0, y }, { width, y } }, (sample - 1) * 2 + 1)
      end

      if (os.clock() - self.resumedAt) > UPDATE_TIMER then
        coroutine.yield(segment, totalSegments, sample, samplesPerSegment)
      end
    end
    table.insert(self.meshes, meshes)
  end
  coroutine.yield(0, 0, 0, 0, true)
end

return self