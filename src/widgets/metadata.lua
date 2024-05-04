local Node      = require 'src.ui.node'
local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local Select    = require 'src.ui.select'
local UIWidget  = require 'src.widgets.ui'

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
  local elems = Container.placeFormLike({
    { Label(0, 0, 'Title'),   { Textfield(0, 0, 100, chart.metadata.musicTitle,  function(value) logs.log(value) end), } },
    { Label(0, 0, 'Artist'),  { Textfield(0, 0, 100, chart.metadata.musicArtist, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Charter'), { Textfield(0, 0, 100, chart.metadata.chartAuthor, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Music'), { Textfield(0, 0, 100, chart.metadata.musicAudio, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Jacket'), { Textfield(0, 0, 100, chart.metadata.jacketImage, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Illustrator'), { Textfield(0, 0, 100, chart.metadata.jacketIllustrator, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Difficulty'), {
      Select(0, 0, {
        'BEGINNER',
        'NORMAL',
        'HYPER',
        'EXTREME',
      }, function(value) logs.log(value) end, chart.metadata.chartDifficulty + 1),
    } },
    { Label(0, 0, 'Level'), { Textfield(0, 0, 100, chart.metadata.chartLevel, function(value) logs.log(value) end), } },
    { Label(0, 0, 'Preview'), {
      Textfield(0, 0, 100, chart.metadata.musicPreviewStart, function(value) logs.log(value) end),
      Label(0, 0, 'to'),
      Textfield(0, 0, 100, chart.metadata.musicPreviewStart + chart.metadata.musicPreviewLength, function(value) logs.log(value) end),
    } },
  }, WIDTH)

  ---@type love.Image?
  self.jacketImg = nil
  self:updateJacket()

  local root = Container({
    JacketPreview(WIDTH, self.jacketImg),
    Container(elems, x, WIDTH),
    Button(10, HEIGHT - 10 - 24, 'Settings...', function()
      --openWidget(ChartSettings(), true)
    end),
  })

  MetadataWidget.super.new(self, x, y, root)
  self.width = WIDTH
  self.height = HEIGHT
  self.title = 'Metadata'
end

function MetadataWidget:updateJacket()
  if chart.metadata.jacketImage and chart.metadata.jacketImage ~= '' and chart.chartDir then
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