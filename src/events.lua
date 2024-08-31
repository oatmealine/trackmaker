local conductor = require 'src.conductor'
local renderer  = require 'src.renderer'
local widgets   = require 'src.widgets'
local logs      = require 'src.logs'

-- globaled to avoid dependency hell issues
events = {}

---@param event XDRVNote | XDRVGearShift | XDRVDrift
function events.onNotePlace(event)
  logs.logFile('event : onNotePlace')
  events.onNotesModify(event)
end
---@param event XDRVNote | XDRVGearShift | XDRVDrift
function events.onNoteRemove(event)
  logs.logFile('event : onNoteRemove')
  events.onNotesModify(event)
end
---@param event XDRVNote | XDRVGearShift | XDRVDrift
function events.onNoteAlter(event)
  logs.logFile('event : onNoteAlter')
  events.onNotesModify(event)
end
---@param event (XDRVNote | XDRVGearShift | XDRVDrift)?
function events.onNotesModify(event)
  logs.logFile('event : onNotesModify')
end
---@param event XDRVBPMChange | XDRVWarp | XDRVStop | XDRVStopSeconds | XDRVScroll | XDRVTimeSignature | XDRVComboTicks | XDRVLabel | XDRVFake | XDRVSceneEvent | XDRVCheckpoint
function events.onEventPlace(event)
  logs.logFile('event : onEventPlace')

  events.onEventsModify(event)
end
---@param event XDRVBPMChange | XDRVWarp | XDRVStop | XDRVStopSeconds | XDRVScroll | XDRVTimeSignature | XDRVComboTicks | XDRVLabel | XDRVFake | XDRVSceneEvent | XDRVCheckpoint
function events.onEventRemove(event)
  logs.logFile('event : onEventRemove')

  events.onEventsModify(event)
end
---@param event XDRVBPMChange | XDRVWarp | XDRVStop | XDRVStopSeconds | XDRVScroll | XDRVTimeSignature | XDRVComboTicks | XDRVLabel | XDRVFake | XDRVSceneEvent | XDRVCheckpoint
function events.onEventAlter(event)
  logs.logFile('event : onEventAlter')

  events.onEventsModify(event)
end
---@param event (XDRVBPMChange | XDRVWarp | XDRVStop | XDRVStopSeconds | XDRVScroll | XDRVTimeSignature | XDRVComboTicks | XDRVLabel | XDRVFake | XDRVSceneEvent | XDRVCheckpoint)?
function events.onEventsModify(event)
  logs.logFile('event : onEventsModify')

  if not event or event.bpm or event.warp or event.stop or event.stopSeconds or event.timeSignature then
    chart.ensureInitialBPM()
    conductor.loadTimings(chart)
  end
  renderer.updateTimingEvents()
end

---@param thing XDRVThing
function events.onThingPlace(thing)
  logs.logFile('event : onThingPlace')

  if thing.note or thing.gearShift or thing.drift then
    events.onNotePlace(thing)
  else
    events.onEventPlace(thing)
  end
  events.onChartEdit(thing)
end
---@param thing XDRVThing
function events.onThingRemove(thing)
  logs.logFile('event : onThingRemove')

  if thing.note or thing.gearShift or thing.drift then
    events.onNoteRemove(thing)
  else
    events.onEventRemove(thing)
  end
  events.onChartEdit(thing)
end
---@param thing XDRVThing
function events.onThingAlter(thing)
  logs.logFile('event : onThingAlter')

  if thing.note or thing.gearShift or thing.drift then
    events.onNoteAlter(thing)
  else
    events.onEventAlter(thing)
  end
  events.onChartEdit(thing)
end

---@param thing XDRVThing?
function events.onChartEdit(thing)
  logs.logFile('event : onChartEdit')

  conductor.initStates()
end
function events.onChartLoad()
  logs.logFile('event : onChartLoad')

  chart.ensureInitialBPM()
  conductor.reset()
  conductor.loadFromChart({ chart = chart.chart, metadata = chart.metadata }, chart.chartDir)
  widgets.callEvent('chartUpdate')
  renderer.updateTimingEvents()
end