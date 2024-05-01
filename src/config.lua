local self = {}

local json = require 'lib.json'

self.config = {
  ---@type string[]
  recent = {},
  volume = 1.0,
  musicRate = 1.0,
  beatTick = false,
  noteTick = false,
}
self.defaults = deepcopy(self.config)

local CONFIG_FILENAME = 'config.json'

-- prefers tab1 with type mismatches; prefers tab2 with value mismatches
-- with the exception of numbered indices
local function mergeTable(tab1, tab2)
  local tab = {}
  for k, v1 in pairs(tab1) do
    local v2 = tab2[k]
    if type(v1) ~= type(v2) then
      tab[k] = v1
    else
      if type(v1) == 'table' then
        tab[k] = mergeTable(v1, v2)
      else
        tab[k] = v2
      end
    end
  end
  for k, v2 in ipairs(tab2) do
    tab[k] = v2
  end
  return tab
end

function self.save()
  love.filesystem.write(CONFIG_FILENAME, json.encode(self.config))
end
function self.load()
  local parsed = {}
  if love.filesystem.getInfo(CONFIG_FILENAME, 'file') then
    parsed = json.decode(love.filesystem.read(CONFIG_FILENAME))
  end

  self.config = mergeTable(self.defaults, parsed)
end

function self.appendRecent(filepath)
  for i = #self.config.recent, 1, -1 do
    if self.config.recent[i] == filepath then
      table.remove(self.config.recent, i)
    end
  end
  table.insert(self.config.recent, 1, filepath)
  if #self.config.recent > 10 then
    table.remove(self.config.recent, 11)
  end
  self.save()
end

return self