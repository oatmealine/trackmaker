--[[
-------------------------------------------------------------------------------
-- @author Colby Klein
-- @author Landon Manning
-- @copyright 2016
-- @license MIT/X11
-------------------------------------------------------------------------------
                  .'@@@@@@@@@@@@@@#:
              ,@@@@#;            .'@@@@+
           ,@@@'                      .@@@#
         +@@+            ....            .@@@
       ;@@;         '@@@@@@@@@@@@.          @@@
      @@#         @@@@@@@@++@@@@@@@;         `@@;
    .@@`         @@@@@#        #@@@@@          @@@
   `@@          @@@@@` Cirno's  `@@@@#          +@@
   @@          `@@@@@  Perfect   @@@@@           @@+
  @@+          ;@@@@+   Math     +@@@@+           @@
  @@           `@@@@@  Library   @@@@@@           #@'
 `@@            @@@@@@          @@@@@@@           `@@
 :@@             #@@@@@@.    .@@@@@@@@@            @@
 .@@               #@@@@@@@@@@@@;;@@@@@            @@
  @@                  .;+@@#'.   ;@@@@@           :@@
  @@`                            +@@@@+           @@.
  ,@@                            @@@@@           .@@
   @@#          ;;;;;.          `@@@@@           @@
    @@+         .@@@@@          @@@@@           @@`
     #@@         '@@@@@#`    ;@@@@@@          ;@@
      .@@'         @@@@@@@@@@@@@@@           @@#
        +@@'          '@@@@@@@;            @@@
          '@@@`                         '@@@
             #@@@;                  .@@@@:
                :@@@@@@@++;;;+#@@@@@@+`
                      .;'+++++;.
--]]
local modules = (...) and (...):gsub('%.init$', '') .. ".modules." or ""

---@class cpml
---@field vec3 cpml.vec3
---@field mat4 cpml.mat4
local cpml = {
	_LICENSE = "CPML is distributed under the terms of the MIT license. See LICENSE.md.",
	_URL = "https://github.com/excessive/cpml",
	_VERSION = "1.2.9",
	_DESCRIPTION = "Cirno's Perfect Math Library: Just about everything you need for 3D games. Hopefully."
}

local files = {
	"bvh",
	"color",
	"constants",
	"intersect",
	"mat4",
	"mesh",
	"octree",
	"quat",
	"simplex",
	"utils",
	"vec2",
	"vec3",
	"bound2",
	"bound3",
}

for _, file in ipairs(files) do
	cpml[file] = require(modules .. file)
end

return cpml
