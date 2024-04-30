local self = {}

local nfd = require 'nfd'
local threads = require 'src.threads'

-- most of this stolen from loenn - thank you for figuring this out!
-- https://github.com/CelestialCartographers/Loenn/blob/340e1af719ade1ba0c8682141c9f50c3f95ee783/src/utils/filesystem.lua

function self.supportWindowsInThreads()
  return love.system.getOS() ~= 'OS X'
end

function self.getDirSeparator()
  return (love.system.getOS() == 'Windows') and '\\' or '/'
end

-- Crashes on Windows if using / as path separator
local function fixNFDPath(path)
  if not path then
    return
  end

  local userOS = love.system.getOS()

  if userOS == 'Windows' then
    return string.gsub(path, '/', '\\')
  else
    return path
  end
end

function self.openDialog(path, filter, callback)
  path = fixNFDPath(path)

  if callback then
    if self.supportWindowsInThreads() then
      local code = [[
        local args = {...}
        local channelName, path, filter = unpack(args)
        local channel = love.thread.getChannel(channelName)

        local nfd = require('nfd')

        local res = nfd.open(filter, path)
        channel:push(res)
      ]]

      return threads.createStartWithCallback(code, callback, path, filter)
    else
      local result = nfd.open(filter, path)

      if result then
        callback(result)
      end

      return false, false
    end
  else
    return nfd.open(filter, path)
  end
end

function self.saveDialog(path, filter, callback)
  path = fixNFDPath(path)

  if callback then
    if self.supportWindowsInThreads() then
      local code = [[
        local args = {...}
        local channelName, path, filter = unpack(args)
        local channel = love.thread.getChannel(channelName)

        local nfd = require('nfd')

        local res = nfd.save(filter, path)
        channel:push(res)
      ]]

      return threads.createStartWithCallback(code, callback, path, filter)

    else
      callback(nfd.save(filter, path))

      return false, false
    end
  else
    return nfd.save(filter, path)
  end
end

return self