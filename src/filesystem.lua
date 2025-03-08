local self = {}

-- hack to load c libs in fused mode
-- https://love2d.org/forums/viewtopic.php?t=86149
if MACOS then
  local base = love.filesystem.getSourceBaseDirectory()
  package.preload['nfd'] = package.loadlib(base..'/nfd.so', 'luaopen_nfd')
end

local success, nfd = pcall(require, 'nfd')

if not success then
  error(
    'Failed to load NFD library! Did you forget to add nfd.dll/nfd.so? ' ..
    '(base dir: ' .. love.filesystem.getSourceBaseDirectory() .. ')\n' ..
    nfd
  )
end

local threads = require 'src.threads'
local config  = require 'src.config'

-- most of this stolen from loenn - thank you for figuring this out!
-- https://github.com/CelestialCartographers/Loenn/blob/340e1af719ade1ba0c8682141c9f50c3f95ee783/src/utils/filesystem.lua

function self.supportWindowsInThreads()
  if config.config.noMultithreading then return false end
  return not MACOS
end

function self.getDirSeparator()
  return WINDOWS and '\\' or '/'
end

-- Crashes on Windows if using / as path separator
local function fixNFDPath(path)
  if not path then
    return
  end

  if WINDOWS then
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