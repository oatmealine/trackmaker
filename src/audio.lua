local _M = {}

---@class SoundPool
---@field base love.Source
---@field sounds love.Source[]
---@field volume number
local pool = {}

function pool:new()
  local newSource = self.base:clone()
  return newSource
end
function pool:setVolume(volume)
  self.volume = volume
end
function pool:play(volume, pitch)
  volume = volume or 0.5
  pitch = pitch or 1
  if pitch == 0 then pitch = 1 end
  local source = self:new()
  source:setVolume(clamp(volume * self.volume, 0, 1))
  source:setPitch(pitch)
  source:play()
  return source
end
-- ONLY WORKS FOR MONO SOUNDS
function pool:playSpatial(x, y, volume, pitch)
  if self.base:getChannelCount() ~= 1 then
    print('refusing to play spatial sound for non-mono sound')
    return
  end

  volume = volume or 0.5
  pitch = pitch or 1
  if pitch == 0 then pitch = 1 end

  local source = self:new()
  source:setPosition(x, y, 0)
  source:setVolume(clamp(volume * self.volume, 0, 1))
  source:setPitch(pitch)
  source:play()
  return source
end
pool.__index = pool

function _M.makeSoundPool(filename)
  local soundPool = {
    base = love.audio.newSource(filename, 'static'),
    sounds = {},
    volume = 1,
  }
  return setmetatable(soundPool, pool)
end

return _M