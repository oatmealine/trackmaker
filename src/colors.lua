-- common colors for various ui elements

local schemes = {
  {
    key = 'legacy',
    name = 'Legacy',

    colors = {
      appBackground = rgb(0, 0, 0),
      background = rgb(0.1, 0.1, 0.1),
      border = rgb(0.2, 0.2, 0.2),

      element = rgb(0.15, 0.15, 0.15),
      hover = rgb(0.2, 0.2, 0.2),
      active = rgb(0.25, 0.25, 0.25),
      down = rgb(0.1, 0.1, 0.1),

      text = rgb(1, 1, 1),
      textSecondary = rgb(0.7, 0.7, 0.7),
      textTertiary = rgb(0.5, 0.5, 0.5),

      window = rgb(0.15, 0.15, 0.15),
      windowFocused = rgb(0.2, 0.2, 0.2),

      modes = {
        insert = rgb(0.15, 0.05, 0.7),
        append = rgb(1, 0.9, 0.2),
        rewrite = rgb(0.9, 0.1, 1),
      },

      borderRadius = 2,
    }
  },
  {
    key = 'catppuccin_latte',
    name = 'Catppuccin Latte',
    link = 'https://github.com/Catppuccin/catppuccin/',

    colors = {
      -- mantle
      background = hex('e6e9ef'),
      -- surface0
      border = hex('ccd0da'),

      -- base
      element = hex('eff1f5'),
      -- surface0
      hover = hex('ccd0da'),
      -- surface1
      active = hex('bcc0cc'),
      -- base
      down = hex('eff1f5'),

      -- base
      window = hex('eff1f5'),
      -- surface0
      windowFocused = hex('ccd0da'),

      -- text
      text = hex('4c4f69'),
      -- overlay2
      textSecondary = hex('7c7f93'),
      -- surface2
      textTertiary = hex('acb0be'),
    }
  },
  {
    key = 'catppuccin_frappe',
    name = 'Catppuccin Frappé',
    link = 'https://github.com/Catppuccin/catppuccin/',

    colors = {
      -- mantle
      background = hex('292c3c'),
      -- surface0
      border = hex('414559'),

      -- base
      element = hex('303446'),
      -- surface0
      hover = hex('414559'),
      -- surface1
      active = hex('51576d'),
      -- base
      down = hex('303446'),

      -- base
      window = hex('303446'),
      -- surface0
      windowFocused = hex('414559'),

      -- text
      text = hex('c6d0f5'),
      -- overlay2
      textSecondary = hex('949cbb'),
      -- surface2
      textTertiary = hex('626880'),
    }
  },
  {
    key = 'catppuccin_macchiato',
    name = 'Catppuccin Macchiato',
    link = 'https://github.com/Catppuccin/catppuccin/',

    colors = {
      -- mantle
      background = hex('1e2030'),
      -- surface0
      border = hex('363a4f'),

      -- base
      element = hex('24273a'),
      -- surface0
      hover = hex('363a4f'),
      -- surface1
      active = hex('494d64'),
      -- base
      down = hex('24273a'),

      -- base
      window = hex('24273a'),
      -- surface0
      windowFocused = hex('363a4f'),

      -- text
      text = hex('cad3f5'),
      -- overlay2
      textSecondary = hex('939ab7'),
      -- surface2
      textTertiary = hex('5b6078'),
    }
  },
  {
    key = 'catppuccin_mocha',
    name = 'Catppuccin Mocha',
    link = 'https://github.com/Catppuccin/catppuccin/',

    colors = {
      -- mantle
      background = hex('181825'),
      -- surface0
      border = hex('313244'),

      -- base
      element = hex('1e1e2e'),
      -- surface0
      hover = hex('313244'),
      -- surface1
      active = hex('45475a'),
      -- base
      down = hex('1e1e2e'),

      -- base
      window = hex('1e1e2e'),
      -- surface0
      windowFocused = hex('313244'),

      -- text
      text = hex('cdd6f4'),
      -- overlay2
      textSecondary = hex('9399b2'),
      -- surface2
      textTertiary = hex('585b70'),
    }
  },
  {
    key = 'love',
    name = 'Love',
    link = 'https://love.holllo.cc',

    colors = {
      background = hex('1F1731'),
      border = hex('2A2041'),

      element = hex('1F1731'),
      hover = hex('2A2041'),
      active = hex('2A2041'),
      down = hex('1F1731'),

      window = hex('1F1731'),
      windowFocused = hex('2A2041'),

      text = hex('F2EFFF'),
      textSecondary = hex('E6DEFF'),
      textTertiary = hex('ABABAB'),

      borderRadius = 0,
    }
  },
  {
    key = 'love_light',
    name = 'Love (Light)',
    link = 'https://love.holllo.cc',

    colors = {
      background = hex('F2EFFF'),
      border = hex('E6DEFF'),

      element = hex('F2EFFF'),
      hover = hex('E6DEFF'),
      active = hex('E6DEFF'),
      down = hex('F2EFFF'),

      window = hex('F2EFFF'),
      windowFocused = hex('E6DEFF'),

      text = hex('1F1731'),
      textSecondary = hex('2A2041'),
      textTertiary = hex('474747'),

      borderRadius = 0,
    }
  },
  {
    key = 'w95',
    name = 'Windows 95',

    colors = {
      background = hex('c0c0c0'),
      border = hex('000000'),

      element = hex('c0c0c0'),
      hover = hex('000080'),
      hoverText = hex('ffffff'),
      active = hex('000080'),
      activeText = hex('ffffff'),
      down = hex('000080'),
      downText = hex('ffffff'),

      dull = hex('808080'),

      window = hex('a0a0a0'),
      windowText = hex('c0c0c0'),
      windowFocused = hex('000080'),
      windowFocusedText = hex('ffffff'),

      text = hex('000000'),
      textSecondary = hex('808080'),
      textTertiary = hex('808080'),

      borderRadius = 0,
    }
  },
  {
    key = 'w95alt',
    name = 'Wannabe Windows 95',

    colors = {
      background = hex('ffffff'),
      border = hex('a6a6a6'),

      element = hex('ffffff'),
      hover = hex('3096fa'),
      hoverText = hex('ffffff'),
      active = hex('3096fa'),
      activeText = hex('ffffff'),
      down = hex('3096fa'),
      downText = hex('ffffff'),

      dull = hex('a6a6a6'),

      window = hex('808080'),
      windowText = hex('ffffff'),
      windowFocused = hex('3096fa'),
      windowFocusedText = hex('ffffff'),

      text = hex('000000'),
      textSecondary = hex('808080'),
      textTertiary = hex('808080'),

      borderRadius = 0,
    }
  },
}

local function getScheme(key)
  for _, scheme in ipairs(schemes) do
    if scheme.key == key then
      return scheme
    end
  end
end

local base = deepcopy(getScheme('legacy').colors)

local scheme = deepcopy(base)
local schemeName = 'legacy'

local meta = {}
meta.__index = meta

local function nuke(tab)
  for k in pairs(tab) do
    tab[k] = nil
  end
end
local function mergeOver(base, tab)
  for k, v in pairs(tab) do
    if base[k] and type(v) == 'table' then
      mergeOver(base[k], v)
    else
      base[k] = v
    end
  end
end

function meta.setScheme(key)
  local newScheme = getScheme(key) and getScheme(key).colors or base
  schemeName = getScheme(key) and key or 'legacy'
  nuke(scheme)
  mergeOver(scheme, base)
  mergeOver(scheme, newScheme)
end
function meta.getSchemes()
  return schemes
end
function meta.getScheme()
  return schemeName
end

local self = setmetatable(scheme, meta)

return self