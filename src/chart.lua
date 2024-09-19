local self = {}

local xdrv           = require 'lib.xdrv'
local conductor      = require 'src.conductor'
local logs           = require 'src.logs'
local config         = require 'src.config'
local filesystem     = require 'src.filesystem'
local sm             = require 'lib.sm'
sm.print = function(s) logs.logFile('sm.lua: ' .. tostring(s)) end
local ImportSMWidget = require 'src.widgets.importsm'
local widgets        = require 'src.widgets'
local exxdriver      = require 'src.exxdriver'
local sort           = require 'lib.sort'

self.loaded = false
self.loadedScript = false
---@type XDRVThing[]
self.chart = nil
---@type XDRVMetadata
self.metadata = nil
---@type string
self.chartDir = nil
---@type string
self.chartLocation = nil

local function updateTitle()
  if self.loaded then
    local dirtyMark = ''
    if self.isDirty() then dirtyMark = ' ·' end
    love.window.setTitle(
      self.metadata.musicTitle ..
      ' ' .. self.diffMark() ..
      ' - trackmaker' .. dirtyMark
    )
  else
    love.window.setTitle('trackmaker')
  end
end

local MAX_HISTORY_LENGTH = 50

---@alias Memory { message: string?, chart: XDRVThing[] }
---@type Memory[]
self.history = {}
self.savedAtHistoryIndex = 1
---@type Memory[]
self.future = {}
function self.clearHistory()
  self.history = {}
  self.savedAtHistoryIndex = 1
  self.future = {}
end
function self.insertHistory(message)
  table.insert(self.history, {
    message = message,
    chart = deepcopy(self.chart),
  })

  if #self.history > MAX_HISTORY_LENGTH then
    table.remove(self.history, 1)
  end

  if #self.future > 0 then
    self.future = {}
    if self.savedAtHistoryIndex >= #self.history then
      -- invalidate, there's no way to get back to where we were again
      -- since the save point was in the future, which we just wiped
      self.savedAtHistoryIndex = -1
    end
  end

  updateTitle()
end

function self.isDirty()
  return self.savedAtHistoryIndex ~= #self.history or (#self.history == #self.future == 0)
end

---@param memory Memory
local function applyMemory(memory)
  self.chart = deepcopy(memory.chart)
end

---@return Memory?
function self.undo()
  if #self.history <= 1 then return end
  local top = table.remove(self.history, #self.history)
  if not top then return end

  table.insert(self.future, 1, top)
  applyMemory(self.history[#self.history])

  if #self.future > MAX_HISTORY_LENGTH then
    table.remove(self.future, #self.future)
  end

  events.onChartEdit()
  updateTitle()

  return top
end
---@return Memory?
function self.redo()
  local top = table.remove(self.future, 1)
  if not top then return end

  applyMemory(top)

  table.insert(self.history, top)

  if #self.history > MAX_HISTORY_LENGTH then
    table.remove(self.history, 1)
  end

  events.onChartEdit()
  updateTitle()

  return top
end

function self.markDirty()
  -- when metadata gets undoing, this should no longer be necessary
  self.savedAtHistoryIndex = -1
  updateTitle()
end

function self.diffMark()
  return '[' .. xdrv.formatDifficultyShort(self.metadata.chartDifficulty) .. lpad(tostring(self.metadata.chartLevel), 2, '0') .. ']'
end

function self.sort()
  -- wikipedia describes an insertion sort's advantages as follows:
  -- - [...]
  -- - Efficient for (quite) small data sets, much like other quadratic (i.e.,
  --   O(n2)) sorting algorithms
  -- - Adaptive, i.e., efficient for data sets that are already substantially
  --   sorted: the time complexity is O(kn) when each element in the input is no
  --   more than k places away from its sorted position
  -- - Stable; i.e., does not change the relative order of elements with equal
  --   keys
  -- - [...]
  -- this seems ideal for us, as the sort call here is mostly a sanity check.
  -- it's called on nearly every operation editing the chart, so having it be
  -- fast for at least most of the time is preferable
  sort.insertion_sort(self.chart, function (a, b) return a and b and a.beat < b.beat end)
end

function self.ensureInitialBPM()
  for _, event in ipairs(self.chart) do
    if event.bpm and event.beat <= 0 then
      self.metadata.chartBPM = event.bpm
      return
    elseif event.bpm then
      break
    end
  end

  table.insert(self.chart, 1, { beat = 0, bpm = self.metadata.chartBPM })
end

function self.tryLoadScript()
  if not chart.metadata.modfilePath then return end
  if not chart.chartDir then return end

  local file, err = io.open(chart.chartDir .. chart.metadata.modfilePath, 'r')
  if not file then
    logs.log('Error loading script: ' .. err)
    return
  end

  local content = file:read('*a')
  file:close()

  local loaded, err = load(content, chart.metadata.modfilePath, 't')
  if not loaded then
    logs.log('Error parsing script: ' .. err)
    return
  end

  chart.loadedScript = loaded
  return true
end

function self.openPath(filepath)
  local file, err = io.open(filepath, 'r')
  if not file then
    logs.log(err)
    return
  end
  local data = file:read('*a')
  file:close()

  local loaded = xdrv.deserialize(data)
  self.chart = loaded.chart or {}
  self.sort()
  self.chartLocation = filepath
  self.metadata = loaded.metadata
  self.chartDir = string.gsub(filepath, '([/\\])[^/\\]+$', '%1')
  self.tryLoadScript()

  self.loaded = true
  updateTitle()

  events.onChartLoad()

  logs.log('Loaded chart ' .. self.metadata.musicTitle .. ' ' .. self.diffMark())
  config.appendRecent(filepath)
  config.save()
end

local FILE_FILTER = 'xdrv'

function self.openChart()
  local songsFolder = exxdriver.getAdditionalFolders()[1]
  -- i could not tell you why appending /? to a path makes it open the folder
  filesystem.openDialog(songsFolder and (songsFolder .. '/?'), FILE_FILTER, function(path)
    if path then
      self.openPath(path)
    else
      logs.log('Open cancelled.')
    end
  end)
end

function self.importPath(filepath, filetype)
  if filetype == 'sm,ssc' then
    local isSSC = string.sub(filepath, -4) == '.ssc'

    local file, err = io.open(filepath, 'r')
    if not file then
      print(err)
      logs.log(err)
      return
    end
    local data = file:read('*a')
    file:close()

    local chart = sm.parse(data, isSSC)

    openWidget(ImportSMWidget(chart, filepath, self.importSM), true)
  end
end

local styleMappings = {
  -- Lasdl;"R<>
  [1] = {
    [0] = { 'gearShift', xdrv.XDRVLane.Left },
    [1] = { 'note',      1 },
    [2] = { 'note',      2 },
    [3] = { 'note',      3 },
    [4] = { 'note',      4 },
    [5] = { 'note',      5 },
    [6] = { 'note',      6 },
    [7] = { 'gearShift', xdrv.XDRVLane.Right },
    [8] = { 'drift',     xdrv.XDRVDriftDirection.Left },
    [9] = { 'drift',     xdrv.XDRVDriftDirection.Right },
  },
  -- <Lasdl;"R>
  [2] = {
    [0] = { 'drift',     xdrv.XDRVDriftDirection.Left },
    [1] = { 'gearShift', xdrv.XDRVLane.Left },
    [2] = { 'note',      1 },
    [3] = { 'note',      2 },
    [4] = { 'note',      3 },
    [5] = { 'note',      4 },
    [6] = { 'note',      5 },
    [7] = { 'note',      6 },
    [8] = { 'gearShift', xdrv.XDRVLane.Right },
    [9] = { 'drift',     xdrv.XDRVDriftDirection.Right },
  },
  -- asdl;"LR<>
  [3] = {
    [0] = { 'note',      1 },
    [1] = { 'note',      2 },
    [2] = { 'note',      3 },
    [3] = { 'note',      4 },
    [4] = { 'note',      5 },
    [5] = { 'note',      6 },
    [6] = { 'gearShift', xdrv.XDRVLane.Left },
    [7] = { 'gearShift', xdrv.XDRVLane.Right },
    [8] = { 'drift',     xdrv.XDRVDriftDirection.Left },
    [9] = { 'drift',     xdrv.XDRVDriftDirection.Right },
  },
  -- asdl;"LRD
  [4] = {
    [0] = { 'note',      1 },
    [1] = { 'note',      2 },
    [2] = { 'note',      3 },
    [3] = { 'note',      4 },
    [4] = { 'note',      5 },
    [5] = { 'note',      6 },
    [6] = { 'gearShift', xdrv.XDRVLane.Left },
    [7] = { 'gearShift', xdrv.XDRVLane.Right },
    [8] = { 'driftRolls' },
  },
}

function self.importSM(chart, filepath, notes, style)
  self.metadata = {
    musicTitle = chart.TITLE or '',
    alternateTitle = chart.TITLETRANSLIT or '',
    musicArtist = chart.ARTIST or '',
    musicAudio = chart.MUSIC or '',
    jacketImage = '',
    jacketIllustrator = '',
    chartAuthor = chart.CREDIT or '',
    chartUnlock = '',
    stageBackground = 'default',
    modfilePath = '',
    chartLevel = -1,
    chartDisplayBPM = chart.DISPLAYBPM or chart.BPMS[1][2],
    chartBoss = false,
    disableLeaderboardUploading = false,
    rpcHidden = false,
    isFlashTrack = false,
    isKeyboardOnly = false,
    isOriginal = false,
    musicPreviewStart = chart.SAMPLESTART or 0,
    musicPreviewLength = chart.SAMPLELENGTH or 0,
    musicVolume = 1,
    musicOffset = chart.OFFSET,
    chartBPM = chart.BPMS[1][2],
    chartTags = { 0, 0, 0, 0 },
    chartDifficulty = xdrv.XDRVDifficulty.Beginner,
  }

  self.chart = {}

  local map = styleMappings[style]

  if notes then
    for _, note in ipairs(notes.notes) do
      local beat = note[1]
      local mapping = map[note[2]]
      local mapType, mapValue = mapping[1], mapping[2]
      if mapType == 'gearShift' then
        if note[3] == '2' then
          table.insert(self.chart, {
            beat = beat,
            gearShiftStart = { lane = mapValue },
          })
        elseif note[3] == '3' then
          table.insert(self.chart, {
            beat = beat,
            gearShiftEnd = { lane = mapValue },
          })
        end
      elseif mapType == 'drift' then
        if note[3] == '2' then
          table.insert(self.chart, {
            beat = beat,
            drift = { direction = mapValue },
          })
        elseif note[3] == '3' then
          table.insert(self.chart, {
            beat = beat,
            drift = { direction = xdrv.XDRVDriftDirection.Neutral },
          })
        end
      elseif mapType == 'driftRolls' then
        if note[3] == '2' then
          table.insert(self.chart, {
            beat = beat,
            drift = { direction = xdrv.XDRVDriftDirection.Left },
          })
        elseif note[3] == '4' then
          table.insert(self.chart, {
            beat = beat,
            drift = { direction = xdrv.XDRVDriftDirection.Right },
          })
        elseif note[3] == '3' then
          table.insert(self.chart, {
            beat = beat,
            drift = { direction = xdrv.XDRVDriftDirection.Neutral },
          })
        end
      elseif mapType == 'note' then
        if note[3] == '1' then
          table.insert(self.chart, {
            beat = beat,
            note = { column = mapValue }
          })
        elseif note[3] == '2' then
          table.insert(self.chart, {
            beat = beat,
            holdStart = { column = mapValue }
          })
        elseif note[3] == '3' then
          table.insert(self.chart, {
            beat = beat,
            holdEnd = { column = mapValue }
          })
        end
      end
    end
  end

  for _, v in ipairs(chart.BPMS or {}) do
    table.insert(self.chart, { beat = v[1], bpm = v[2] })
  end

  for _, v in ipairs(chart.LABELS or {}) do
    table.insert(self.chart, { beat = v[1], label = v[2] })
  end

  for _, v in ipairs(chart.TIMESIGNATURES or {}) do
    table.insert(self.chart, { beat = v[1], timeSignature = { tonumber(v[2]), tonumber(v[3]) } })
  end

  for _, v in ipairs(chart.WARPS or {}) do
    table.insert(self.chart, { beat = v[1], warp = v[2] })
  end

  for _, v in ipairs(chart.DELAYS or {}) do
    -- functionally the same as a stop
    table.insert(self.chart, { beat = v[1], stop = v[2] })
  end

  for _, v in ipairs(chart.STOPS or {}) do
    table.insert(self.chart, { beat = v[1], stop = v[2] })
  end

  for _, v in ipairs(chart.FAKES or {}) do
    table.insert(self.chart, { beat = v[1], fake = v[2] })
  end

  self.chart = xdrv.collapseHoldEnds(self.chart)

  self.sort()

  self.chartDir = string.gsub(filepath, '([/\\])[^/\\]+$', '%1')
  conductor.reset()

  updateTitle()

  self.loaded = true

  events.onChartLoad()

  logs.log('Imported chart ' .. self.metadata.musicTitle .. ' ' .. self.diffMark())
end

function self.importMenu(filetype)
  filesystem.openDialog(nil, filetype, function(path)
    if path then
      self.importPath(path, filetype)
    else
      logs.log('Open cancelled.')
    end
  end)
end

local function save(filepath, noBackup)
  logs.logFile('Saving to ' .. filepath)

  self.sort()

  logs.logFile('Printing data just in case')
  logs.logFile(pretty(chart.chart))

  if not noBackup then
    local oldFile, missing = io.open(filepath, 'r')
    if oldFile then
      local oldFilepath = filepath .. '.old'
      logs.logFile('File exists, backing up to ' .. oldFilepath)
      local oldContents = oldFile:read('*a')
      oldFile:close()
      local backupFile, err = io.open(oldFilepath, 'w')
      if not backupFile then
        logs.log(err)
        return
      end
      backupFile:write(oldContents)
      backupFile:close()
    else
      logs.logFile('File does not already exist')
    end
  end

  local contents = xdrv.serialize({ metadata = self.metadata, chart = self.chart })
  if not DEV then
    contents = '// Made with trackmaker v' .. release.version .. '\n' .. contents
  end

  local file, err = io.open(filepath, 'w')
  if not file then
    logs.log(err)
    return
  end
  file:write(contents)
  file:close()

  logs.log('Saved chart to ' .. filepath)
  if not noBackup then
    chart.savedAtHistoryIndex = #chart.history
    self.chartLocation = filepath
    config.appendRecent(filepath)
  end
  updateTitle()
  config.save()
end

---@param m XDRVMetadata
local function makeChartFilename(m)
  return xdrv.formatDifficulty(m.chartDifficulty) .. '.xdrv'
end

---@param thing XDRVThing
---@return number?
function self.findThing(thing)
  for i, ev in ipairs(self.chart) do
    if ev.beat > thing.beat then
      return
    end
    if beatCmp(ev.beat, thing.beat) and looseComp(thing, ev) then
      return i
    end
  end
end
---@param beat number
---@param type string
---@return number?
function self.findThingOfType(beat, type)
  for i, ev in ipairs(self.chart) do
    if ev.beat > beat then
      return
    end
    if beatCmp(ev.beat, beat) and ev[type] then
      return i
    end
  end
end

function self.removeThing(i)
  local thing = self.chart[i]
  table.remove(self.chart, i)
  events.onThingRemove(thing)
end

---@param thing XDRVThing
function self.placeThing(thing)
  for i, ev in ipairs(self.chart) do
    if beatCmp(ev.beat, thing.beat) and getThingType(ev) == getThingType(thing) then
      -- prevent collisions/overlap
      -- different types have different definitions of a collision, so
      -- we handle them all seperately
      if ev.note then
        if ev.note.column == thing.note.column then
          self.chart[i] = thing
          events.onThingPlace(thing)
          return
        end
      elseif ev.gearShift then
        if ev.gearShift.lane == thing.gearShift.lane then
          self.chart[i] = thing
          events.onThingPlace(thing)
          return
        end
      elseif ev.event then
        -- there's nothing that says you can't use multiple events at the same time
      else
        -- else just remove them anyways
        self.chart[i] = thing
        events.onThingPlace(thing)
        return
      end
    elseif ev.beat > thing.beat then
      table.insert(self.chart, i, thing)
      events.onThingPlace(thing)
      return
    end
  end
  table.insert(self.chart, thing)
  events.onThingPlace(thing)
end

function self.saveChart()
  if not self.chart then return end

  filesystem.saveDialog(self.chartDir .. makeChartFilename(self.metadata), FILE_FILTER, function(path)
    if path then
      save(path)
    else
      logs.log('Save cancelled.')
    end
  end)
end

function self.quickSave()
  if not self.chart then return end
  if not self.chartLocation then
    self.saveChart()
  else
    save(self.chartLocation)
  end
end

local autosaveTimer = 0
local AUTOSAVE_INTERVAL = 60 * 3
--local AUTOSAVE_INTERVAL = 5
function self.update(dt)
  if not (self.isDirty() and self.chart and self.chartLocation) then
    autosaveTimer = 0
  else
    autosaveTimer = autosaveTimer + dt

    if autosaveTimer > AUTOSAVE_INTERVAL then
      logs.log('Autosaving..')
      save(self.chartLocation .. '.auto', true)
      autosaveTimer = autosaveTimer - AUTOSAVE_INTERVAL
    end
  end
end

updateTitle()

return self