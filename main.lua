release = nil
do 
  local t = {}
  t.window = {}
  t.modules = {}
  require 'conf'
  love.conf(t)
  release = t.releases
end

require 'lib.color'

require 'src.util'

-- enables some certain xdrv chart dev specific stuff
DEV = false
-- opens the script on error
DEBUG_SCRIPTS = false

WINDOWS = love.system.getOS() == 'Windows'
MACOS = love.system.getOS() == 'OS X'
LINUX = love.system.getOS() == 'Linux'

fonts = {
  inter_12 = love.graphics.newFont('assets/fonts/Inter-Regular.ttf', 12),
  inter_16 = love.graphics.newFont('assets/fonts/Inter-Regular.ttf', 16),

  fallback_12 = love.graphics.newFont('assets/fonts/Inter-Regular.ttf', 12),
  fallback_16 = love.graphics.newFont('assets/fonts/Inter-Regular.ttf', 16),
}

local config = require 'src.config'

local widgets    = require 'src.widgets'
chart            = require 'src.chart'
local conductor  = require 'src.conductor'
keybinds         = require 'src.keybinds'
local edit       = require 'src.edit'
local renderer   = require 'src.renderer'
local logs       = require 'src.logs'
local threads    = require 'src.threads'
local colors     = require 'src.colors'
local waveform   = require 'src.waveform'
local xdrvColors = require 'src.xdrvcolors'
local preview    = require 'src.preview'
require 'src.events'

local function loadCustomFont(path)
  local file, err = io.open(path, 'r')
  if not file then
    logs.warn('Error loading font: ' .. err)
    return
  end

  local content = file:read('*a')
  file:close()

  if not content then
    logs.warn('Error loading font: empty')
    return
  end

  local name = basename(path)
  return love.filesystem.newFileData(content, name)
end

function initFonts()
  ---@type string | love.FileData
  local uiSrc = 'assets/fonts/' .. config.config.uiFont
  if string.sub(config.config.uiFont, 1, 7) == 'file://' then
    local path = string.sub(config.config.uiFont, 8)
    local file = loadCustomFont(path)
    if not file then
      config.config.uiFont = config.defaults.uiFont
      uiSrc = 'assets/fonts/' .. config.config.uiFont
    else
      uiSrc = file
    end
  end

  local res
  res, fonts.inter_12 = pcall(love.graphics.newFont, uiSrc, config.config.uiFontSize)
  if not res then
    logs.warn(fonts.inter_12)
    fonts.inter_12 = fonts.fallback_12
  end
  fonts.inter_12:setFallbacks(fonts.fallback_12)
  res, fonts.inter_16 = pcall(love.graphics.newFont, uiSrc, config.config.uiFontSize + 4)
  if not res then
    logs.warn(fonts.inter_16)
    fonts.inter_16 = fonts.fallback_16
  end
  fonts.inter_16:setFallbacks(fonts.fallback_16)
  widgets.reloadAssets()
  renderer.updateTimingEvents()
end

local PromptWidget = require 'src.widgets.prompt'

function love.load(args)
  love.keyboard.setKeyRepeat(true)
  config.load()
  initFonts()
  colors.setScheme(config.config.theme)
  xdrvColors.setScheme(config.config.xdrvColors)
  --chart.openChart()

  if config.config.xdrvChartDev then
    DEV = true
  end

  love.window.setVSync(config.config.vsync and 1 or 0)

  local loadedFile
  local loadedFileBeat
  local loadedFileCheckpoint
  local argValue
  for _, arg in ipairs(args) do
    if string.sub(arg, 1, 2) == '--' then
      argValue = nil
      if arg == '--dev' then
        DEV = true
      end
      if arg == '--debug-scripts' then
        DEBUG_SCRIPTS = true
      end
      if arg == '--beat' then
        argValue = 'beat'
      end
      if arg == '--checkpoint' then
        argValue = 'checkpoint'
      end
    else
      if argValue then
        if argValue == 'beat' then
          loadedFileBeat = tonumber(arg)
        end
        if argValue == 'checkpoint' then
          loadedFileCheckpoint = tonumber(arg)
        end
      else
        if not loadedFile then
          loadedFile = arg
        end
      end
    end
  end

  if loadedFile then
    chart.openPath(loadedFile)
    if loadedFileBeat then
      conductor.seekBeats(loadedFileBeat)
    end
    if loadedFileCheckpoint then
      local checkIdx = 0
      for _, event in ipairs(chart.chart) do
        if event.checkpoint then
          checkIdx = checkIdx + 1
          if checkIdx == loadedFileCheckpoint then
            conductor.seekBeats(event.beat)
            logs.log('Jumped to checkpoint ' .. checkIdx .. ' (' .. event.checkpoint .. ')')
            break
          end
        end
      end
    end
  end
end

function love.update(dt)
  conductor.update(dt)
  logs.update(dt)
  threads.update()
  waveform.update()
  chart.update(dt)
end

function love.draw()
  love.graphics.setFont(fonts.inter_12)
  love.graphics.clear(colors.appBackground:unpack())

  local sw, sh, scx, scy = screenCoords()

  renderer.draw()

  widgets.draw()

  logs.draw()

  if edit.viewBinds then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(fonts.inter_16)
    love.graphics.print('Keybinds', 16, 16)

    love.graphics.setFont(fonts.inter_12)

    local y = 48
    for name, bind in pairs(keybinds.binds) do
      if bind.name then
        love.graphics.print(keybinds.formatBind(bind) .. ' - ' .. bind.name, 16, y)
      end
      y = y + 16
    end
  end

  if not chart.loaded then return end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(
    'FPS ' .. love.timer.getFPS()
  , 0, sh - fonts.inter_12:getHeight())
  if not renderer.ignoreCache() then
    love.graphics.print(
      'last draw took ' .. math.floor(renderer.drawProfile * 1000) .. 'ms | FPS ' .. math.floor(1 / renderer.drawProfile)
    , 0, sh - fonts.inter_12:getHeight() * 2)
  end

  local y = 24
  if config.config.debug.undoHistory then
    for i, v in ipairs(chart.history) do
      love.graphics.print(tostring(i), 0, y)
      love.graphics.print((v.message or 'Action') .. (i == #chart.history and ' <-' or ''), 16, y)
      y = y + 14
    end
    for i, v in ipairs(chart.future) do
      love.graphics.print(tostring(i), 0, y)
      love.graphics.print((v.message or 'Action'), 16, y)
      y = y + 14
    end
    love.graphics.print('saved at ' .. chart.savedAtHistoryIndex .. ', #history: ' .. #chart.history .. ', #future: ' .. #chart.future, 16, y)
  end
  if config.config.debug.modsDisplay then
    for mod in pairs(preview.getKnownModNames()) do
      local value = string.format('%.2f', preview.getEasedValue(mod))
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.print(mod .. ':', 2, y + 2)
      love.graphics.print(value, 160 + 2, y + 2)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(mod .. ':', 0, y)
      love.graphics.print(value, 160, y)
      y = y + 14
    end
  end
end

function love.mousepressed(x, y, button)
  if widgets.mousepressed(x, y, button) then return end
  renderer.mousepressed(x, y, button)
end
function love.mousemoved(x, y)
  widgets.mousemoved(x, y)
end
function love.mousereleased(x, y, button)
  if widgets.mousereleased(x, y, button) then return end
  renderer.mousereleased(x, y, button)
end
function love.keypressed(key, scancode, isrepeat)
  if widgets.keypressed(key, scancode, isrepeat) then
    return
  end
  if widgets.eatsInputs() then return end
  edit.keypressed(key, scancode, isrepeat)
end
function love.keyreleased(key, scancode)
  if widgets.eatsInputs() then return end
  edit.keyreleased(key, scancode)
end
function love.wheelmoved(ox, oy)
  renderer.wheelmoved(oy)
end

function love.textinput(t)
  widgets.textinput(t)
end

function love.resize(w, h)
  renderer.resize(w, h)
end

shouldQuitOnSave = false
function love.quit()
  if chart.loaded and chart.isDirty() and not shouldQuitOnSave then
    shouldQuitOnSave = true
    openWidget(PromptWidget('Your chart has unsaved changes. Would you like to save?', {
      { text = 'Yes', click = function() chart.quickSave() end},
      { text = 'No', click = function() love.event.quit(0) end },
      { text = 'Cancel', click = function() shouldQuitOnSave = false end } }), true)
    return true
  end
end