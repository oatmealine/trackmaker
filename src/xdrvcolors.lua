local config = require 'src.config'
local self = {}

-- replace pattern:
-- (\w+): \{r: (.+), g: (.+), b: (.+), a: (.+)\}
-- $1 = rgb($2, $3, $4),

self.schemes = {
  {
    name = 'Default',
    colors = {
      LeftGear = rgb(0.31, 0.8, 1),
      Column1 = rgb(0.67, 0.5, 1),
      Column2 = rgb(1, 0.83, 0.33),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 0.83, 0.33),
      Column6 = rgb(0.67, 0.5, 1),
      RightGear = rgb(1, 0.6084906, 0.96161675),
    },
  },
  {
    name = 'Basic',
    colors = {
      LeftGear = rgb(0.25485048, 0.57589406, 0.7830189),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(1, 1, 1),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 1, 1),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(0.7264151, 0.29125133, 0.36982247),
    },
  },
  {
    name = 'Bite',
    colors = {
      LeftGear = rgb(0.27450982, 0.8980392, 1),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(0.8117647, 0.62352943, 1),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(0.8117648, 0.62352943, 1),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.92156863, 0.2),
    },
  },
  {
    name = 'CIEL',
    colors = {
      LeftGear = rgb(0.32941177, 0.36078432, 0.62352943),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(0.7882353, 0.5764706, 1),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(0.78823537, 0.5764706, 1),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(0.29803923, 0.6862745, 1),
    },
  },
  {
    name = 'IBEX',
    colors = {
      LeftGear = rgb(0.8352941, 1, 0.14901961),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(1, 0.54901963, 0.7529412),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 0.54901963, 0.75294125),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.56078434, 0.2),
    },
  },
  {
    name = 'Ignia',
    colors = {
      LeftGear = rgb(0.3137255, 0.8, 1),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(1, 0.8313726, 0.3254902),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 0.83137256, 0.3254902),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.40392157, 0.9411765),
    },
  },
  {
    name = 'Middy',
    colors = {
      LeftGear = rgb(0.6509804, 0.49019608, 0.7607843),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(1, 0.6, 0.6),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 0.6, 0.6),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.8392157, 0.35686275),
    },
  },
  {
    name = 'Minus',
    colors = {
      LeftGear = rgb(0.023529412, 1, 0.5529412),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(0.6901961, 0.5254902, 1),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(0.6901961, 0.5254902, 1),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.27450982, 0.6),
    },
  },
  {
    name = 'Modern',
    colors = {
      LeftGear = rgb(0.3915094, 0.74018246, 1),
      Column1 = rgb(1, 1, 1),
      Column2 = rgb(0.6650944, 0.857395, 1),
      Column3 = rgb(1, 1, 1),
      Column4 = rgb(1, 1, 1),
      Column5 = rgb(1, 0.7216981, 0.96543974),
      Column6 = rgb(1, 1, 1),
      RightGear = rgb(1, 0.4009434, 0.92674416),
    },
  },
}

self.default = self.schemes[1]
self.scheme = self.default

local function fromUnity(c)
  return rgb(c.r, c.g, c.b)
end

local function deserializeScheme(c)
  local new = {}
  for k, v in pairs(c) do
    new[k] = hex(v)
  end
  return new
end

function self.setScheme(name)
  if name == 'custom' then
    self.scheme = { name = 'Custom', colors = deserializeScheme(config.config.xdrvCustomColors) }
    return
  end
  for _, scheme in ipairs(self.schemes) do
    if scheme.name == name then
      self.scheme = scheme
      return
    end
  end
end

function self.setCustom(scheme)
  config.config.xdrvCustomColors = {
    LeftGear = fromUnity(scheme[7]):hex(),
    Column1 = fromUnity(scheme[1]):hex(),
    Column2 = fromUnity(scheme[2]):hex(),
    Column3 = fromUnity(scheme[3]):hex(),
    Column4 = fromUnity(scheme[4]):hex(),
    Column5 = fromUnity(scheme[5]):hex(),
    Column6 = fromUnity(scheme[6]):hex(),
    RightGear = fromUnity(scheme[8]):hex(),
  }
  print(pretty(config.config.xdrvCustomColors))
end

return self