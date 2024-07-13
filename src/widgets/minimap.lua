local conductor = require 'src.conductor'
local ContextWidget = require 'src.widgets.context'
local renderer      = require 'src.renderer'

---@class MinimapWidget : Widget
local MinimapWidget = Widget:extend()

function MinimapWidget:new(x, y)
  MinimapWidget.super.new(self, x, y)
  self.dragAnywhere = true
  self.hasWindowDecorations = false
  self.resizable = false

  self.width = 1
  self.height = 1

  self.mx = 0
  self.my = 0

  self.canvasHeight = love.graphics.getHeight() - 24
  love.graphics.setDefaultFilter('nearest', 'nearest')
  self.canvas = love.graphics.newCanvas(6, self.canvasHeight / 2)
  love.graphics.setDefaultFilter('linear', 'linear')

  self.hovered = false
  self.isMovable = false
end

function MinimapWidget:click(x, y, button)
  if button ~= 2 then return end

  local entries = {}

  table.insert(entries, { 'Close', function() self.delete = true end })

  openWidget(ContextWidget(self.x + x, self.y + y, entries))
end

function MinimapWidget:moveFrame(x, y)
  MinimapWidget.super.moveFrame(self, x, y)
  self.mx, self.my = self:translateLocal(x, y)
  self.hovered = self.mx >= 0 and self.mx <= self.width and self.my >= 0 and self.my <= self.height
end

function MinimapWidget:getYFromBeat(beat, dur)
  return (1 - (conductor.timeAtBeat(beat) / dur)) * self.canvas:getHeight()
end

function MinimapWidget:draw()
  local canvasHeight = love.graphics.getHeight() - 24
  if self.canvasHeight ~= canvasHeight then
    love.graphics.setDefaultFilter('nearest', 'nearest')
    self.canvas = love.graphics.newCanvas(6, self.canvasHeight / 2)
    love.graphics.setDefaultFilter('linear', 'linear')
  end

  self.height = sh - 24

  if chart.loaded then
    self.width = 50
  else
    self.width = 0
    return
  end

  self.x = sw - self.width
  self.y = 24

  love.graphics.push()
  love.graphics.origin()

  love.graphics.setCanvas(self.canvas)
  love.graphics.clear()

  local chartDur = conductor.getDuration()

  for _, event in ipairs(chart.chart) do
    if event.note then
      love.graphics.setColor(renderer.getColumnColor(event.note.column):unpack())
      love.graphics.points(event.note.column - 1, self:getYFromBeat(event.beat, chartDur))
    end
    if event.gearShift then
      love.graphics.setColor(renderer.getLaneColor(event.gearShift.lane):alpha(0.9):unpack())
      local startY = self:getYFromBeat(event.beat, chartDur)
      local endY = self:getYFromBeat(event.beat + event.gearShift.length, chartDur)
      love.graphics.rectangle('fill', (event.gearShift.lane - 1) * 3, startY, 3, endY - startY)
    end
  end

  love.graphics.pop()

  love.graphics.setCanvas()

  love.graphics.setColor(0, 0, 0, 0.4)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  love.graphics.setColor(0.2, 0.2, 0.2, 1)
  love.graphics.line(0, 0, 0, self.height)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(self.canvas, 0, 0, 0, self.width / self.canvas:getWidth(), self.height / self.canvas:getHeight())

  local beatS, beatE = renderer.yToBeat(sh), renderer.yToBeat(0)
  local timeS, timeE = conductor.timeAtBeat(beatS), conductor.timeAtBeat(beatE)

  local height = math.abs(timeE - timeS) / chartDur * self.height

  love.graphics.setColor(1, 1, 1, self.hovered and 0.3 or 0.2)
  love.graphics.rectangle('fill', 0, self.height - height - clamp(timeS / chartDur, 0, 1) * (self.height - height), self.width, height)

  if self.hovered and love.mouse.isDown(1) then
    conductor.seek((1 - clamp((self.my - height) / (self.height - height), 0, 1)) * chartDur)
  end
end

return MinimapWidget