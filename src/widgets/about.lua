local colors = require 'src.colors'

---@class AboutWidget : Widget
local AboutWidget = Widget:extend()

local jillo = love.graphics.newImage('assets/sprites/jillo.png')
local JILLO_SCALE = 0.7
local WOBBLE_DURATION = 0.4

local function outSine(x) return math.sin(x * (math.pi * 0.5)) end

function AboutWidget:new(x, y)
  AboutWidget.super.new(self, x, y)
  self.width = 250
  self.height = 255

  self.lastClick = 0
  self.title = 'About'
end

function AboutWidget:click(x, y, button)
  local jy = 128
  if
    x > self.width/2 - jillo:getWidth() / 2 * JILLO_SCALE and
    x < self.width/2 + jillo:getWidth() / 2 * JILLO_SCALE and
    y > jy - jillo:getHeight() / 2 * JILLO_SCALE and
    y < jy + jillo:getHeight() / 2 * JILLO_SCALE
  then
    self.lastClick = love.timer.getTime()
  end
end

function AboutWidget:draw()
  love.graphics.setColor(colors.background:unpack())
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)

  local t = love.timer.getTime()
  local wobble = outSine(math.max(math.min((WOBBLE_DURATION - (t - self.lastClick)) / WOBBLE_DURATION, 1), 0)) * 0.25

  local sx, sy = JILLO_SCALE + math.cos(t * 11) * wobble, JILLO_SCALE + math.sin(t * 11) * wobble

  local offset = 8

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(fonts.inter_16)
  love.graphics.printf({{colors.text:unpack()}, 'trackmaker', {colors.textTertiary:unpack()}, ' v' .. release.version}, 0, offset, self.width, 'center')
  love.graphics.setColor(colors.textSecondary:unpack())
  love.graphics.setFont(fonts.inter_12)
  love.graphics.printf('A GUI chart editor for EX-XDRiVER', 0, offset + 22, self.width, 'center')
  love.graphics.printf('by oatmealine', 0, offset + 40, self.width, 'center')
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(jillo, self.width/2, offset + 40 + 80, 0, sx, sy, jillo:getWidth()/2, jillo:getHeight()/2)
  love.graphics.setColor(colors.textSecondary:unpack())
  love.graphics.printf('Licensed under the zlib license\nCopyright © 2024\nJill "oatmealine" Monoids\nSee license.txt for more information', 0, offset + 180, self.width, 'center')
end

return AboutWidget