local objc = require 'lib.objc'
local ffi = require 'ffi'
local bit = require 'bit'
local utf8 = require 'utf8'

local ActionBarWidget = require 'src.widgets.actionbar'

objc.loadFramework('AppKit')

local function NSString(str)
  return objc.NSString:stringWithUTF8String(str)
end

local self = {}

-- constants / enums
local NSCriticalRequest = ffi.new('NSUInteger', 0)

local NSEventModifierFlagShift = ffi.new('NSUInteger', bit.lshift(1, 17))
local NSEventModifierFlagOption = ffi.new('NSUInteger', bit.lshift(1, 19))
local NSEventModifierFlagCommand = ffi.new('NSUInteger', bit.lshift(1, 20))

local NSControlStateValueOff = ffi.new('NSUInteger', 0)
local NSControlStateValueOn = ffi.new('NSUInteger', 1)

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

objc.addMethod(AppDelegateClass, 'applicationDockMenu:', '@:@',
  function()
    local appMenu = objc.NSMenu:alloc():init()
    appMenu:autorelease()

    local menuItem = objc.NSMenuItem:alloc():initWithTitle_action_keyEquivalent(
      NSString('gurt'),
      'terminate:',
      NSString('')
    )
    appMenu:addItem(menuItem)

    return appMenu
  end
)

local actionNameMap = {}

objc.addMethod(AppDelegateClass, 'validateMenuItem:', 'B@:@',
  function(self, sel, menu)
    local item = actionNameMap[tostring(menu.action)]
    if not item then return YES end

    local disabled = item.disabled and item.disabled()
    if disabled then return NO end

    if item.toggle then
      local value = item.value()
      menu:setState(value and NSControlStateValueOn or NSControlStateValueOff)
    end

    return YES
  end
)

local function contextToNSMenuItem(item)
  if item[1] then
    local actionName
    if item.click then
      actionName = 'custom' .. string.gsub(item[1], '[ .]', '') .. ':'
      actionNameMap[actionName] = item
      objc.addMethod(AppDelegateClass, actionName, '@:@',
        function()
          item.click()
        end
      )
    end
    local menuItem = objc.NSMenuItem:alloc():init()

    menuItem.title = NSString(item[1])
    if actionName then menuItem.action = actionName end
    if item.bind then
      local bind = item.bind
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
      if bind.shift then flags = bit.bor(flags, NSEventModifierFlagShift)   end
      if bind.ctrl  then flags = bit.bor(flags, NSEventModifierFlagCommand) end
      if bind.alt   then flags = bit.bor(flags, NSEventModifierFlagOption)  end
      menuItem.keyEquivalentModifierMask = flags
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

function self.injectMenuBar()
  local mainMenu = app.mainMenu

  -- let's locate the "window" menu, so that we can place everything before it
  local windowMenuIdx = mainMenu:indexOfItemWithTitle(NSString('Window'))

  -- store the "about" item, as we'll inject it into the primary menu
  local aboutItem
  -- same with the "exit" item
  local exitItem

  -- add our usual actionbar menu items

  for _, menu in ipairs(ActionBarWidget.items) do
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

  -- initialize our delegate to handle events
  -- todo: maybe move to a seperate method..?
  local appDelegate = objc.AppDelegate:alloc():init()
  appDelegate:autorelease()
  app:setDelegate(appDelegate)
end

function self.bounceDockApp()
  app:requestUserAttention(NSCriticalRequest)
end

function self.clean()
  pool:drain()
end

return self