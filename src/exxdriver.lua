local json = require 'lib.json'

-- utilities for dealing with the game itself

local self = {}

local COMPANY_IDENTIFIER = 'EX-XDRiVER'
local GAME_IDENTIFIER = 'XDRV'

function self.getSavePath()
  -- https://docs.unity3d.com/ScriptReference/Application-persistentDataPath.html

  if LINUX then
    local configHome = os.getenv('XDG_CONFIG_HOME')
    if configHome then
      return configHome .. '/unity3d/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
    local home = os.getenv('HOME')
    if home then
      return home .. '/.config/unity3d/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
  elseif MACOS then
    local home = os.getenv('HOME')
    if home then
      return home .. '/Library/Application Support/com.' .. COMPANY_IDENTIFIER .. '.' .. GAME_IDENTIFIER
    end
  elseif WINDOWS then
    local userProfile = os.getenv('USERPROFILE')
    if userProfile then
      return userProfile .. '/AppData/LocalLow/' .. COMPANY_IDENTIFIER .. '/' .. GAME_IDENTIFIER
    end
  else
    -- unknown
    print('Using unsupported platform ' .. love.system.getOS() .. ', expect issues')
    return ''
  end
  
  print('Failed to find platform path')
  return ''
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