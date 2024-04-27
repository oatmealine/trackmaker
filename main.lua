local conductor = require 'src.conductor'
require 'lib.color'
require 'src.util'
local edit      = require 'src.edit'

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

  if not chart.loaded then return end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(
    'FPS ' .. love.timer.getFPS() .. '\n' ..
    'b: ' .. conductor.beat .. '\n' ..
    edit.modeName(edit.getMode()) .. '\n' ..
    '\n' ..
    chart.metadata.musicTitle .. '\n' ..
    chart.metadata.musicArtist .. '\n' ..
    chart.metadata.chartAuthor
  )
end

function love.mousepressed(x, y, button)
  if button == 1 and not chart.loaded then
    chart.openChart()
  end
end
function love.keypressed(key, scancode)
  edit.keypressed(key, scancode)
end
function love.wheelmoved(ox, oy)
  renderer.wheelmoved(oy)
end