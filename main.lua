local xdrv = require "lib.xdrv"
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

local conductor = require 'src.conductor'
keybinds        = require 'src.keybinds'
local edit      = require 'src.edit'
local renderer  = require 'src.renderer'
local chart     = require 'src.chart'
local widgets   = require 'src.widgets'

fonts = {
  inter_12 = love.graphics.newFont('assets/fonts/Inter-Regular.ttf', 12),
}

function love.load()
  love.keyboard.setKeyRepeat(true)
  chart.openChart()
end

function love.update(dt)
  conductor.update(dt)
end

---@type table<number, { [1]: string, [2]: love.Text }>
local footerFieldCache = {}

function love.draw()
  love.graphics.setFont(fonts.inter_12)

  renderer.draw()

  widgets.draw()

  local footerFields = {
    { 'Difficulty', xdrv.formatDifficulty(chart.metadata.chartDifficulty) .. ' ' .. chart.metadata.chartLevel },
    { 'Snap', getDivision(edit.quantIndex) .. 'th' },
    { 'Beat', string.format('%.3f', conductor.beat) },
    { 'Time', formatTime(conductor.time) },
    { 'BPM', string.format('%.3f', conductor.getBPM()) },
  }

  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  local FOOTER_GAP = 4
  local FOOTER_MARGIN = 8
  local width = FOOTER_MARGIN
  for i, f in ipairs(footerFields) do
    if not (footerFieldCache[i] and footerFieldCache[i][1] == f[2]) then
      footerFieldCache[i] = { f[2], love.graphics.newText(fonts.inter_12, f[2]) }
    end
    local text = footerFieldCache[i][2]
    width = width + text:getWidth() + FOOTER_GAP
  end
  width = width - FOOTER_GAP + FOOTER_MARGIN
  love.graphics.rectangle('fill', scx - width/2, sh - 24 - 16, width, 24, 12, 12)
  love.graphics.setColor(1, 1, 1, 1)
  local x = scx - width/2 + FOOTER_MARGIN
  for i, f in ipairs(footerFields) do
    local text = footerFieldCache[i][2]
    love.graphics.draw(text, x, sh - 24 - 12)
    x = x + text:getWidth() + FOOTER_GAP
  end

  if edit.viewBinds then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print('Keybinds', 16, 16)
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
  )
end

function love.mousepressed(x, y, button)
  if button == 1 and not chart.loaded then
    chart.openChart()
  end
  widgets.mousepressed(x, y, button)
end
function love.mousemoved(x, y)
  widgets.mousemoved(x, y)
end
function love.mousereleased(x, y, button)
  widgets.mousereleased(x, y, button)
end
function love.keypressed(key, scancode)
  edit.keypressed(key, scancode)
end
function love.wheelmoved(ox, oy)
  renderer.wheelmoved(oy)
end