local conductor = require 'src.conductor'
require 'lib.color'
require 'src.util'

local t = {}
t.window = {}
t.modules = {}
require 'conf'
love.conf(t)
release = t.releases

local renderer = require 'src.renderer'
local chart    = require 'src.chart'

function love.load()
  chart.openChart()
end

function love.update(dt)
  conductor.update(dt)
end

function love.draw()
  renderer.draw()

  if not chart.metadata then return end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(
    'FPS ' .. love.timer.getFPS() .. '\n' ..
    'b: ' .. conductor.beat .. '\n' ..
    '\n' ..
    chart.metadata.MUSIC_TITLE .. '\n' ..
    chart.metadata.MUSIC_ARTIST .. '\n' ..
    chart.metadata.CHART_AUTHOR
  )
end

function love.mousepressed(x, y, button)
  if button == 1 and not chart then
    chart.openChart()
  end
end
function love.keypressed(key)
  if key == 'space' then
    if conductor.isPlaying() then
      conductor.pause()
    else
      conductor.play()
    end
  elseif key == 'down' then
    conductor.seekDelta(-conductor.beatsToSeconds(1))
  elseif key == 'up' then
    conductor.seekDelta(conductor.beatsToSeconds(1))
  elseif key == 's' and love.keyboard.isDown('lctrl') or love.keyboard.isDown('rctrl') then
    chart.saveChart()
  end
end
function love.wheelmoved(ox, oy)
  renderer.wheelmoved(oy)
end