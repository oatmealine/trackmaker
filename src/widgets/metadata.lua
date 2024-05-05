local Node      = require 'src.ui.node'
local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local Select    = require 'src.ui.select'
local UIWidget  = require 'src.widgets.ui'
local conductor = require 'src.conductor'
local ChartSettingsWidget = require 'src.widgets.chartsettings'

local logs      = require 'src.logs'

---@class MetadataWidget : UIWidget
local MetadataWidget = UIWidget:extend()

local WIDTH = 300
local HEIGHT = 610

---@class JacketPreview : Node
local JacketPreview = Node:extend()

---@param size number
---@param image love.Image?
function JacketPreview:new(size, image)
  JacketPreview.super.new(self)
  -- jackets are square
  self.width = size
  self.height = size
  self.image = image
end
function JacketPreview:draw()
  love.graphics.setColor(0.4, 0.4, 0.4, 1)
  love.graphics.rectangle('fill', 0, 0, self.width, self.height)
  love.graphics.setColor(1, 1, 1, 1)
  if self.image then
    love.graphics.draw(self.image, 0, 0, 0, self.width / self.image:getWidth(), self.height / self.image:getHeight())
  end
end

function MetadataWidget:new(x, y)
  ---@type love.Image?
  self.jacketImg = nil
  self:updateJacket()

  MetadataWidget.super.new(self, x, y, self:getContainer())
  self.width = WIDTH
  self.height = HEIGHT
  self.title = 'Metadata'
end

function MetadataWidget:getContainer()
  local metadata = chart.metadata or {}

  local elems = Container.placeFormLike({
    { Label(0, 0, 'Title'),   { Textfield(0, 0, 100, metadata.musicTitle or '',  function(value)
      chart.metadata.musicTitle = value
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Artist'),  { Textfield(0, 0, 100, metadata.musicArtist or '', function(value)
      chart.metadata.musicArtist = value
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Charter'), { Textfield(0, 0, 100, metadata.chartAuthor or '', function(value)
      chart.metadata.chartAuthor = value
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Music'),   { Textfield(0, 0, 100, metadata.musicAudio or '', function(value)
      chart.metadata.musicAudio = value
      if chart.chartDir then
        conductor.loadSong(chart.chartDir .. chart.metadata.musicAudio)
      end
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Jacket'),  { Textfield(0, 0, 100, metadata.jacketImage or '', function(value)
      chart.metadata.jacketImage = value
      self:updateJacket()
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Illustrator'), { Textfield(0, 0, 100, metadata.jacketIllustrator or '', function(value)
      chart.metadata.jacketIllustrator = value
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Difficulty'), {
      Select(0, 0, {
        'BEGINNER',
        'NORMAL',
        'HYPER',
        'EXTREME',
      }, function(value)
        chart.metadata.chartDifficulty = value - 1
        chart.markDirty()
      end, (metadata.chartDifficulty or 0) + 1),
    } },
    { Label(0, 0, 'Level'),   { Textfield(0, 0, 100, tostring(metadata.chartLevel or 0), function(value)
      chart.metadata.chartLevel = tonumber(value)
      chart.markDirty()
    end), } },
    { Label(0, 0, 'Preview'), {
      Textfield(0, 0, 100, metadata.musicPreviewStart or 0, function(value)
        chart.metadata.musicPreviewStart = tonumber(value)
        chart.markDirty()
      end),
      Label(0, 0, 'to'),
      Textfield(0, 0, 100, (metadata.musicPreviewStart or 0) + (metadata.musicPreviewLength or 0), function(value)
        chart.metadata.musicPreviewLength = tonumber(value) - chart.metadata.musicPreviewStart
        chart.markDirty()
      end),
    } },
  }, WIDTH)

  for _, elem in ipairs(elems) do
    if not chart.loaded then
      elem.disabled = true
    end
  end

  local root = Container({
    JacketPreview(WIDTH, self.jacketImg),
    Container(elems, 0, WIDTH),
    Button(10, HEIGHT - 10 - 24, 'Settings...', function()
      openWidget(ChartSettingsWidget(), true)
    end),
  })

  return root
end

function MetadataWidget:event(name)
  if name == 'chartUpdate' then
    self:updateJacket()
    self.container = self:getContainer()
  end
end

function MetadataWidget:updateJacket()
  if chart.loaded and chart.metadata.jacketImage and chart.metadata.jacketImage ~= '' and chart.chartDir then
    local path = chart.chartDir .. chart.metadata.jacketImage
    local file, err = io.open(path, 'rb')
    if not file then
      logs.log(err)
      return
    end
    local data = file:read('*a')
    file:close()
    local fileData = love.filesystem.newFileData(data, chart.metadata.jacketImage)
    self.jacketImg = love.graphics.newImage(fileData)
  end
end

return MetadataWidget