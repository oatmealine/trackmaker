local logs = require "src.logs"
local self = {}

---@type love.Decoder
self.decoder = nil
---@type table<number, table<number, number>>
self.samples = {}

local BUFFER_SIZE = 4096

local CANVAS_WIDTH = 2048
local SAMPLE_RATE = 1024
local CANVAS_PIXEL_RATE = 256

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

  self.canvas = love.graphics.newCanvas(CANVAS_WIDTH * self.decoder:getChannelCount(), love.graphics.getSystemLimits().texturesize, {
    format = 'r8',
    msaa = 4,
    dpiscale = 1,
  })
  ---@type love.Image[]
  self.waveforms = self.drawWaveforms()
  ---@type love.Quad[]
  self.quads = {}
  for i = 1, self.decoder:getChannelCount() do
    self.quads[i] = love.graphics.newQuad((i - 1) * CANVAS_WIDTH, 0, CANVAS_WIDTH, self.canvas:getHeight(), self.canvas:getWidth(), self.canvas:getHeight())
  end
  self.canvas = nil
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

function self.drawWaveforms()
  local totalHeight = CANVAS_PIXEL_RATE * self.decoder:getDuration()
  self.totalHeight = totalHeight
  local size = self.canvas:getHeight()
  local channels = self.decoder:getChannelCount()

  local textures = {}

  love.graphics.push('all')
  love.graphics.origin()
  love.graphics.setColor(1, 1, 1)

  local meshes = {}
  for i = 1, channels do
    meshes[i] = love.graphics.newMesh(size * 2, 'strip', 'stream')
  end

  for yBase = 0, totalHeight, size do
    print('rendering: ', yBase)
    love.graphics.setCanvas(self.canvas)

    love.graphics.clear()

    for y = 0, size - 1 do
      local yTotal = y + yBase
      local startSample = math.floor(yTotal / totalHeight * self.decoder:getDuration() * SAMPLE_RATE)
      local endSample = math.floor((yTotal + 1) / totalHeight * self.decoder:getDuration() * SAMPLE_RATE) - 1
      local sums = {}
      for i = 1, channels do
        sums[i] = 0
      end
      for idx = startSample, endSample do
        local smps = getSample(math.floor(idx / SAMPLE_RATE * self.decoder:getSampleRate()))
        if not smps then break end
        for i, smp in ipairs(smps) do
          sums[i] = sums[i] + math.abs(smp) / (endSample - startSample)
        end
      end
      for i = 1, channels do
        local width = sums[i] * CANVAS_WIDTH
        meshes[i]:setVertices({ { 0, y }, { width, y } }, 1 + y * 2)
      end
    end

    for i, mesh in ipairs(meshes) do
      love.graphics.draw(mesh, (i - 1) * CANVAS_WIDTH)
    end

    love.graphics.setCanvas()

    table.insert(textures, love.graphics.newImage(self.canvas:newImageData(), { mipmaps = true }))
  end

  love.graphics.pop()

  return textures
end

return self