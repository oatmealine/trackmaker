local xdrv = require 'lib.xdrv'
local edit = require 'src.edit'
local conductor = require 'src.conductor'
local colors = require 'src.colors'

---@class InfobarWidget : Widget
local InfobarWidget = Widget:extend()

---@type table<number, { [1]: string, [2]: love.Text, [3]: number }>
local footerFieldCache = {}

function InfobarWidget:new()
  InfobarWidget.super.new(self)
  self.isMovable = false
  self.hasWindowDecorations = false
end

local GAP = 14
local MARGIN = 12
local ROUND = 10
local HEIGHT = 40
local MODE_WIDTH = 72

function InfobarWidget:click(x, y, button)
  if button == 1 and x > self.width - MODE_WIDTH then
    edit.cycleMode()
  end
end

function InfobarWidget:drawFrame()
  local footerFields = {
    { 'Difficulty', chart.loaded and (xdrv.formatDifficulty(chart.metadata.chartDifficulty) .. ' ' .. chart.metadata.chartLevel) or '' },
    { 'Snap', formatSnap(edit.quantIndex) },
    { 'Beat', string.format('%.3f', conductor.beat) },
    { 'Time', formatTime(conductor.time) },
    { 'BPM', string.format('%.3f', conductor.getBPM()) },
  }

  local width = MARGIN
  for i, f in ipairs(footerFields) do
    if not (footerFieldCache[i] and footerFieldCache[i][1] == f[2]) then
      local cache = footerFieldCache[i]
      local text = love.graphics.newText(fonts.inter_16, f[2])
      footerFieldCache[i] = { f[2], text, math.max(text:getWidth(), cache and cache[3] or 0) }
    end
    local cache = footerFieldCache[i]
    width = width + cache[3] + GAP
  end
  width = width - GAP + MARGIN

  self.width = width + MARGIN + MODE_WIDTH
  self.height = HEIGHT
  self.x = love.graphics.getWidth()/2 - width / 2
  self.y = love.graphics.getHeight() - 16 - self.height

  love.graphics.push()

  -- rounded to help w/ text legibility
  love.graphics.translate(round(self.x), round(self.y))

  love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  love.graphics.rectangle('fill', 0, 0, width, self.height, ROUND, ROUND)
  love.graphics.setColor(1, 1, 1, 1)
  local x = MARGIN
  for i, f in ipairs(footerFields) do
    local cache = footerFieldCache[i]
    local text = cache[2]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(text, round(x + (cache[3] - text:getWidth())/2), 2)
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.printf(f[1], round(x) - 50, 22, round(cache[3]) + 50*2, 'center')
    x = x + cache[3] + GAP
  end

  local mode = edit.getMode()

  if mode == edit.Mode.None then
    love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
  elseif mode == edit.Mode.Insert then
    love.graphics.setColor(colors.modes.insert:unpack())
  elseif mode == edit.Mode.Append then
    love.graphics.setColor(colors.modes.append:unpack())
  elseif mode == edit.Mode.Rewrite then
    love.graphics.setColor(colors.modes.rewrite:unpack())
  end
  love.graphics.rectangle('fill', width + MARGIN, 0, MODE_WIDTH, self.height, ROUND, ROUND)
  if mode == edit.Mode.None or mode == edit.Mode.Insert then
    love.graphics.setColor(1, 1, 1, 1)
  else
    love.graphics.setColor(0, 0, 0, 1)
  end
  love.graphics.setFont(fonts.inter_16)
  love.graphics.printf(edit.modeName(mode), round(width + MARGIN), round(self.height/2 - fonts.inter_16:getHeight()/2), MODE_WIDTH, 'center')
  love.graphics.setFont(fonts.inter_12)

  love.graphics.pop()
end

return InfobarWidget