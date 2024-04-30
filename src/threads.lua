-- stolen from https://github.com/CelestialCartographers/Loenn/blob/340e1af719ade1ba0c8682141c9f50c3f95ee783/src/utils/threads.lua

local threadHandler = {}

threadHandler._threads = {}

function threadHandler.createStartWithCallback(threadCode, callback, ...)
  local thread = love.thread.newThread(threadCode)
  local channel = love.timer.getTime()

  threadHandler._threads[channel] = {thread = thread, callback = callback, channel = channel}
  thread:start(channel, ...)

  return channel, thread
end

function threadHandler.release(channelName)
  if threadHandler._threads[channelName] then
    local channel = love.thread.getChannel(channelName)
    local thread = threadHandler._threads[channelName].thread

    channel:release()
    thread:release()

    threadHandler._threads[channelName] = nil
  end
end

local function runFunctionOnData(channel, func)
  while true do
    local res = channel:pop()

    if res ~= nil then
      func(res)
    else
      break
    end
  end
end

function threadHandler.update()
  local removed = {}

  for channelName, data in pairs(threadHandler._threads) do
    local thread = data.thread
    local callback = data.callback or function() end
    local channel = love.thread.getChannel(channelName)

    runFunctionOnData(channel, callback)

    if not thread:isRunning() then
      table.insert(removed, channelName)
    end
  end

  for i, channelName in ipairs(removed) do
    threadHandler.release(channelName)
  end
end

return threadHandler