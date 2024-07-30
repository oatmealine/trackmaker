local Container = require 'src.ui.container'
local Button    = require 'src.ui.button'
local Checkmark = require 'src.ui.checkmark'
local Label     = require 'src.ui.label'
local Textfield = require 'src.ui.textfield'
local UIWidget  = require 'src.widgets.ui'

---@class EventEditWidget : UIWidget
local EventEditWidget = UIWidget:extend()

---@param event XDRVThing
function EventEditWidget:new(event)
  print(pretty(event))
  self.editEvent = event
  self.originalEvent = deepcopy(self.editEvent)
  self.type = getThingType(event)

  EventEditWidget.super.new(self, 0, 0, self:getContainer())

  self.title = 'Edit Event'
  self.width = 220
  self.height = 100
end

local eventFields = {
  bpm = { 'number', nil, 'BPM' },
  warp = { 'number', nil, 'Beats' },
  stop = { 'number', nil, 'Beats' },
  stopSeconds = { 'number', nil, 'Seconds' },
  scroll = { 'number', nil, 'x' },
  timeSignature = { 'arr', {
    { 'number', nil, '/' },
    { 'number', nil, nil },
  }},
  comboTicks = { 'number', nil, 'x' },
  label = { 'string', nil, nil },
  fake = { 'number', nil, 'Beats' },
}

function EventEditWidget:getRows(field, store)
  if not field then
    return {
      { Label(0, 0, 'Editing not supported...') }
    }
  end

  local t = field[1]
  if t == 'number' then
    return {
      { Textfield(0, 0, 40, tostring(store[1]), function(value) store[1] = tonumber(value) self:updateFields() end), }
    }
  elseif t == 'string' then
    return {
      { Textfield(0, 0, 140, store[1], function(value) store[1] = value self:updateFields() end), }
    }
  elseif t == 'arr' then
    local resRow = {}
    for i, f in ipairs(field[2]) do
      store[i] = store[i] or {}
      for _, row in ipairs(self:getRows(f, store[i])) do
        for _, elem in ipairs(row) do
          table.insert(resRow, elem)
        end
      end
    end
    return { resRow }
  end
end

function EventEditWidget:updateFields()
  -- TODO
end
function EventEditWidget:fillStore(obj)
  obj = obj or self.editEvent[self.type]

  if type(obj) == 'string' or type(obj) == 'number' then
    return { obj }
  elseif type(obj) == 'table' then
    local res = {}
    for _, v in ipairs(obj) do
      table.insert(res, self:fillStore(v))
    end
    return res
  end
end

function EventEditWidget:getContainer()
  local rows = {
    {
      Label(0, 0, 'Beat'), Textfield(0, 0, 40, self.editEvent.beat, function(value) self.editEvent.beat = tonumber(value) end),
    }
  }

  self.dataStore = self:fillStore()

  print(self.type)
  local fields = eventFields[self.type]
  for _, field in ipairs(self:getRows(fields, self.dataStore)) do
    table.insert(rows, field)
  end

  table.insert(rows, {
    Button(40, 10, 'Save', function() self:place(true) self.delete = true end),
    Button(40, 10, 'Delete', function() self:place(false) self.delete = true end),
  })

  return Container(Container.placeRows(rows, self.width))
end

function EventEditWidget:place(shouldPlace)
  local existingEvent = chart.findThing(self.originalEvent)
  if existingEvent then
    chart.removeThing(existingEvent)
  end

  if shouldPlace then
    chart.placeThing(self.editEvent)
  end
end

return EventEditWidget