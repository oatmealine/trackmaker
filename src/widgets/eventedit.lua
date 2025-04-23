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
  self.editEvent = event
  self.originalEvent = deepcopy(event)
  self.type = getThingType(event)

  EventEditWidget.super.new(self, 0, 0, self:getContainer())

  self.title = 'Edit Event'
  self.width = 220
  self.height = 100
end

local eventNames = {
  bpm = 'BPM Change',
  warp = 'Warp',
  stop = 'Stop',
  stopSeconds = 'Stop',
  scroll = 'Scroll Speed',
  timeSignature = 'Time Signature',
  comboTicks = 'Combo Ticks',
  label = 'Label',
  fake = 'Fake',
  event = 'Stage Event',
  measureLine = 'Measure Line',
}
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
  fake = { 'arr', {
    { 'number', nil, 'Beats' },
    { 'number', nil, 'Column' },
  }},
  measureLine = { 'number', nil, 'Lane' },
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
      {
        Textfield(0, 0, 40, tostring(store[1]), function(value) store[1] = tonumber(value) self:updateFields() end),
        field[3] and Label(0, 0, field[3]) or nil,
      }
    }
  elseif t == 'string' then
    return {
      {
        Textfield(0, 0, 140, store[1], function(value) store[1] = value self:updateFields() end),
        field[3] and Label(0, 0, field[3]) or nil,
      }
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

function EventEditWidget:getStore(field, store)
  field = field or eventFields[self.type]
  store = store or self.dataStore

  if not field then return end
  if not store then return end
  if field[1] == 'string' or field[1] == 'number' then
    return store[1]
  elseif field[1] == 'arr' then
    local res = {}
    for i, v in ipairs(store) do
      table.insert(res, self:getStore(field[2][i], v))
    end
    return res
  end
end
function EventEditWidget:updateFields()
  self.editEvent[self.type] = self:getStore()
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
      Label(0, 0, eventNames[self.type], fonts.inter_16)
    },
    --[[{
      Label(0, 0, 'Beat'), Textfield(0, 0, 40, self.editEvent.beat, function(value) self.editEvent.beat = tonumber(value) end),
    }]]
  }

  self.dataStore = self:fillStore()

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
    chart.insertHistory('Place event')
  else
    chart.insertHistory('Remove event')
  end
end

return EventEditWidget