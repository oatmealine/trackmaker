local objc = require 'lib.objc'
local ffi = require 'ffi'
local bit = require 'bit'
local utf8 = require 'utf8'
local config = require 'src.config'

local ActionBarWidget = require 'src.widgets.actionbar'

objc.loadFramework('AppKit')

ffi.cdef([[
typedef struct NSEdgeInsets {
  CGFloat top;
  CGFloat left;
  CGFloat bottom;
  CGFloat right;
} NSEdgeInsets;
]])

local function NSEdgeInsets(top, left, bottom, right)
  return ffi.new('NSEdgeInsets', { top = top, left = left, bottom = bottom, right = right })
end

---@alias NSString string
---@return NSString
local function NSString(str)
  return objc.NSString:stringWithUTF8String(str)
end
---@alias NSInteger integer
---@return NSInteger
local function NSInteger(n)
  return ffi.new('NSInteger', n) --[[@as NSInteger]]
end

local function NSSize(w, h)
  return ffi.new('CGSize', { width = w, height = h })
end

local self = {}

-- constants / enums
local NSCriticalRequest = NSInteger(0)

local NSEventModifierFlagShift = bit.lshift(1, 17)
local NSEventModifierFlagOption = bit.lshift(1, 19)
local NSEventModifierFlagCommand = bit.lshift(1, 20)

local NSControlStateValueOff = NSInteger(0)
local NSControlStateValueOn = NSInteger(1)

local NSControlSizeRegular = NSInteger(0)
local NSControlSizeSmall = NSInteger(1)
local NSControlSizeMini = NSInteger(2)
local NSControlSizeLarge = NSInteger(3)

local NSUserInterfaceLayoutOrientationHorizontal = NSInteger(0)
local NSUserInterfaceLayoutOrientationVertical = NSInteger(1)

local NSLayoutAttributeLeft = NSInteger(1)
local NSLayoutAttributeRight = NSInteger(2)
local NSLayoutAttributeTop = NSInteger(3)
local NSLayoutAttributeBottom = NSInteger(4)
local NSLayoutAttributeLeading = NSInteger(5)
local NSLayoutAttributeTrailing = NSInteger(6)
local NSLayoutAttributeWidth = NSInteger(7)
local NSLayoutAttributeHeight = NSInteger(8)
local NSLayoutAttributeCenterX = NSInteger(9)
local NSLayoutAttributeCenterY = NSInteger(10)
local NSLayoutAttributeBaseline = NSInteger(11)
local NSLayoutAttributeFirstBaseline = NSInteger(12)

local NO = ffi.new('BOOL', 0)
local YES = ffi.new('BOOL', 1)

local keyToNSKey = {
  ['f1']  = utf8.char(0xF704),
  ['f2']  = utf8.char(0xF705),
  ['f3']  = utf8.char(0xF706),
  ['f4']  = utf8.char(0xF707),
  ['f5']  = utf8.char(0xF708),
  ['f6']  = utf8.char(0xF709),
  ['f7']  = utf8.char(0xF70A),
  ['f8']  = utf8.char(0xF70B),
  ['f9']  = utf8.char(0xF70C),
  ['f10'] = utf8.char(0xF70D),
  ['f11'] = utf8.char(0xF70E),
  ['f12'] = utf8.char(0xF70F),
}

local pool = objc.NSAutoreleasePool:alloc():init()
local app = objc.NSApplication:sharedApplication()

-- delegate will only get initialized and set at the end of self.injectMenuBar
local AppDelegateClass = objc.newClass('AppDelegate')

objc.addMethod(AppDelegateClass, 'openRecentItem:', 'v@:@',
  function(self, cmd, item)
    local path = ffi.string(item.representedObject:UTF8String())
    chart.openPath(path)
  end
)

objc.addMethod(AppDelegateClass, 'applicationDockMenu:', '@:@',
  function()
    local appMenu = objc.NSMenu:alloc():init()
    appMenu:autorelease()

    for _, recentItem in ipairs(config.config.recent) do
      local menuItem = objc.NSMenuItem:alloc():initWithTitle_action_keyEquivalent(
        NSString(truncEnd(recentItem, 48)),
        --NSString(basename(recentItem)),
        'openRecentItem:',
        NSString('')
      )
      menuItem.representedObject = NSString(recentItem)
      menuItem:autorelease()

      appMenu:addItem(menuItem)
    end

    return appMenu
  end
)

---@type table<string, ActionBarItem>
local itemNameMap = {}
---@type table<integer, string>
local itemTagMap = {}
local tagIdx = 0

objc.addMethod(AppDelegateClass, 'menubarClick:', 'v@:@',
  function(self, cmd, menuItem)
    local name = ffi.string(menuItem.representedObject:UTF8String())
    local item = itemNameMap[name]
    if not item then return end
    item.click()
  end
)
objc.addMethod(AppDelegateClass, 'sliderDrag:', 'v@:@',
  function(self, cmd, slider)
    local name = itemTagMap[tonumber(slider.tag)]
    local item = itemNameMap[name]
    if not item then return end

    local value = tonumber(slider.doubleValue) --[[@as number]]
    item.set(value)
    local formattedValue = string.format('%.2f', value)
    if item.formatValue then formattedValue = item.formatValue(value) end
    slider.superview.subviews:lastObject().stringValue = NSString(formattedValue)
  end
)

local appDelegate = objc.AppDelegate:alloc():init()
appDelegate:autorelease()

---@param item ActionBarItem
local function contextToNSMenuItem(item)
  if item[1] then
    local menuItem = objc.NSMenuItem:alloc():init()

    itemNameMap[item[1]] = item
    menuItem.representedObject = NSString(item[1])

    menuItem.title = NSString(item[1])
    menuItem.action = 'menubarClick:'
    local bind = item.bind
    if bind then
      local keys = bind.keys
      if not keys then
        keys = bind.keyCodes
      end
      local key = keys[1]
      if keyToNSKey[key] then
        key = keyToNSKey[key]
      end
      menuItem.keyEquivalent = NSString(key)
      local flags = 0
      if bind.shift then flags = bit.bor(flags, NSEventModifierFlagShift  ) end
      if bind.ctrl  then flags = bit.bor(flags, NSEventModifierFlagCommand) end
      if bind.alt   then flags = bit.bor(flags, NSEventModifierFlagOption ) end
      menuItem.keyEquivalentModifierMask = flags
    end

    if item.slider then
      local view = objc.NSStackView:alloc():init()
      view:autorelease()
      view:setTranslatesAutoresizingMaskIntoConstraints(NO)

      local label = objc.NSTextField:labelWithString(NSString(item[1]))
      label:setTranslatesAutoresizingMaskIntoConstraints(NO)
      if type(label.widthAnchor) == 'function' then
		label:widthAnchor():constraintEqualToConstant(150).active = YES
      	label:heightAnchor():constraintEqualToConstant(15).active = YES
      else
      	label.widthAnchor:constraintEqualToConstant(150).isActive = YES
      	label.heightAnchor:constraintEqualToConstant(15).isActive = YES
      end
      label.font = objc.NSFont:systemFontOfSize(12)
      label.textColor = objc.NSColor:grayColor()
      view:addArrangedSubview(label)

      local sliderView = objc.NSStackView:alloc():init()
      sliderView:setTranslatesAutoresizingMaskIntoConstraints(NO)

      local value = item.value()
      local formattedValue = string.format('%.2f', value)
      if item.formatValue then formattedValue = item.formatValue(value) end

      local slider = objc.NSSlider:sliderWithTarget_action(appDelegate, 'sliderDrag:')
      slider.controlSize = NSControlSizeSmall
      slider.doubleValue = value
      slider.tag = tagIdx
      itemTagMap[tagIdx] = item[1]
      tagIdx = tagIdx + 1

      local sliderLabel = objc.NSTextField:labelWithString(NSString(formattedValue))
      sliderLabel:setTranslatesAutoresizingMaskIntoConstraints(NO)
      sliderLabel.font = objc.NSFont:monospacedSystemFontOfSize_weight(12, 0.0)

      sliderView.orientation = NSUserInterfaceLayoutOrientationHorizontal
      sliderView.alignment = NSLayoutAttributeCenterY

      sliderView:addArrangedSubview(slider)
      sliderView:addArrangedSubview(sliderLabel)
      view:addArrangedSubview(sliderView)

      view.edgeInsets = NSEdgeInsets(2, 24, 2, 16)
      view.orientation = NSUserInterfaceLayoutOrientationVertical
      view.alignment = NSLayoutAttributeLeading

      menuItem.view = view
    end

    menuItem:autorelease()
    if item[2] then
      local submenu = objc.NSMenu:alloc():init()
      submenu:autorelease()
      for _, subitem in ipairs(item[2]) do
        submenu:addItem(contextToNSMenuItem(subitem))
      end
      menuItem:setSubmenu(submenu)
    end
    return menuItem
  else
    return objc.NSMenuItem:separatorItem()
  end
end

local sharedWorkspace = objc.NSWorkspace:sharedWorkspace()

local function getPathIcon(path, size)
  size = size or 16
  local icon = sharedWorkspace:iconForFile(NSString(path))
  icon:setSize(NSSize(16, 16))
  return icon
end

objc.addMethod(AppDelegateClass, 'validateMenuItem:', 'B@:@',
  function(self, sel, menuItem)
    local name = ffi.string(menuItem.representedObject:UTF8String())
    local item = itemNameMap[name]
    if not item then return YES end

    local disabled = item.disabled and item.disabled()
    local res = disabled and NO or YES

    if item.slider then
      -- custom view so process it before everything else
      menuItem.view.subviews:lastObject().subviews:firstObject().enabled = not disabled
      return res
    end

    if item.toggle then
      local value = item.value()
      menuItem:setState(value and NSControlStateValueOn or NSControlStateValueOff)
      return res
    end

    if item.getSubmenu then
      local oldSubmenu = menuItem.submenu
      if oldSubmenu ~= nil then
        oldSubmenu:removeAllItems()
      end
      local items = item.getSubmenu()

      local submenu = objc.NSMenu:alloc():init()
      for _, subitem in ipairs(items) do
        local subMenuItem = contextToNSMenuItem(subitem)
        if subitem.representedFile then
          subMenuItem:setImage(getPathIcon(subitem.representedFile))
        end
        submenu:addItem(subMenuItem)
      end

      menuItem:setSubmenu(submenu)

      return res
    end

    if item[2] then
      return res
    end
    if item.click then
      return res
    end

    -- no handler, disable
    return NO
  end
)

function self.injectMenuBar()
  local mainMenu = app.mainMenu

  -- let's locate the "window" menu, so that we can place everything before it
  local windowMenuIdx = mainMenu:indexOfItemWithTitle(NSString('Window'))

  -- store the "about" item, as we'll inject it into the primary menu
  local aboutItem
  -- same with the "exit" item
  local exitItem

  -- add our usual actionbar menu items

  for _, menu in ipairs(ActionBarWidget.barItems) do
    local appMenuItem = objc.NSMenuItem:alloc():init()
    appMenuItem:autorelease()

    local appMenu = objc.NSMenu:alloc():initWithTitle(NSString(menu[1]))
    appMenu:autorelease()

    local items = menu[2]

    for _, item in ipairs(items) do
      -- lua 5.1 not having continues is genuinely so depressing
      if item[1] == 'About' or item[1] == 'Exit' then
        if item[1] == 'About' then aboutItem = item end
        if item[1] == 'Exit' then exitItem = item end
      else
        appMenu:addItem(contextToNSMenuItem(item))
      end
    end

    appMenuItem:setSubmenu(appMenu)

    if menu[1] == 'Help' then
      -- this one goes _after_ the "window" menu..
      mainMenu:addItem(appMenuItem)
    else
      mainMenu:insertItem_atIndex(appMenuItem, windowMenuIdx)
      windowMenuIdx = windowMenuIdx + 1
    end
  end

  -- forcefully insert some new items
  local primaryMenuItem = mainMenu:itemAtIndex(0)
  local primaryMenu = primaryMenuItem.submenu

  -- TODO don't use manual indices for these... a love update could break this
  primaryMenu:removeItemAtIndex(0) -- about
  primaryMenu:insertItem_atIndex(contextToNSMenuItem(aboutItem), 0)

  primaryMenu:removeItemAtIndex(10) -- exit
  primaryMenu:insertItem_atIndex(contextToNSMenuItem(exitItem), 10)

  app:setDelegate(appDelegate)
end

function self.bounceDockApp()
  app:requestUserAttention(NSCriticalRequest)
end

function self.clean()
  pool:drain()
end

return self
