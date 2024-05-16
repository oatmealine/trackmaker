local json = require 'lib.json'

-- utilities for dealing with the game itself

local self = {}

local COMPANY_IDENTIFIER = 'EX-XDRiVER'
local GAME_IDENTIFIER = 'XDRV'

function self.getSavePath()
  -- https://docs.unity3d.com/ScriptReference/Application-persistentDataPath.html

  if love.system.getOS() == 'Linux' then
    local configHome = os.getenv('XDG_CONFIG_HOME')
    if configHome then
      return configHome .. '/unity3d/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
    local home = os.getenv('HOME')
    if home then
      return home .. '/.config/unity3d/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
  elseif love.system.getOS() == 'Windows' then
    local userProfile = os.getenv('USERPROFILE')
    if userProfile then
      return userProfile .. '/AppData/LocalLow/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
  end
  -- unknown
  return nil
end
function self.getColorSchemePath()
  return self.getSavePath() .. '/Data/ColorSchemes'
end
function self.getAdditionalFolders()
  local filePath = self.getSavePath() .. '/Data/additionalSongFolders.json'
  local file = io.open(filePath, 'r')
  if not file then
    -- ignorable error completely
    return {}
  end
  local raw = file:read('*a')
  file:close()
  local data = json.decode(raw)
  return data and data.AdditionalSongFolders or {}
end

return self