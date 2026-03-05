local lovePE = require 'platform.windows.love-pe'

local exeFile, err = io.open(arg[1], 'rb')
if not exeFile then error(err) end
local icoFile, err = io.open(arg[2], 'rb')
if not icoFile then error(err) end
local newFile, err = io.open(arg[3], 'wb')
if not newFile then error(err) end

lovePE.replaceIcon(exeFile, icoFile, newFile)

exeFile:close()
icoFile:close()
newFile:close()