local activeScreen = require('ext.screen').activeScreen
local capitalize   = require('ext.utils').capitalize
local focusScreen  = require('ext.screen').focusScreen
local forceFocus   = require('ext.window').forceFocus

local cache  = {}
local module = { cache = cache }

local getWindowMenuItems = function()
  local win = hs.window.frontmostWindow()
  local app = win:application()
  local appElement = hs.axuielement.applicationElement(app)

  local appMenuBar = hs.fnutils.find(appElement:attributeValue('AXChildren'), function(childElement)
    return childElement:attributeValue('AXRole') == 'AXMenuBar'
  end)

  if not appMenuBar then
    return
  end

  local menuItems = appMenuBar:attributeValue('AXChildren')

  local windowMenu = hs.fnutils.find(menuItems, function(menuItem)
    return menuItem:attributeValue('AXTitle') == 'Window'
  end)

  if not windowMenu then
    return
  end

  local windowMenuItems = windowMenu:attributeValue('AXChildren')[1]:attributeValue('AXChildren')

  return windowMenuItems
end

local pressWindowMenuItem = function(title)
  local windowMenuItems = getWindowMenuItems()

  if not windowMenuItems then
    return
  end

  local match = hs.fnutils.find(windowMenuItems, function(menuItem)
    return menuItem:attributeValue('AXTitle') == title
  end)

  match:doAXPress()
end

local pressWindowMoveResizeMenuItem = function(title)
  local windowMenuItems = getWindowMenuItems()

  local moveAndResizeMenu = hs.fnutils.find(windowMenuItems, function(menuItem)
    return menuItem:attributeValue('AXTitle') == 'Move & Resize'
  end)

  local moveAndResizeMenuItems = moveAndResizeMenu:attributeValue('AXChildren')[1]:attributeValue('AXChildren')

  local match = hs.fnutils.find(moveAndResizeMenuItems, function(menuItem)
    return menuItem:attributeValue('AXTitle') == title
  end)

  match:doAXPress()
end

local getSpacesIdsTable = function()
  local spacesLayout = hs.spaces.allSpaces()
  local spacesIds = {}

  hs.fnutils.each(hs.screen.allScreens(), function(screen)
    local spaceUUID = screen:getUUID()

    local userSpaces = hs.fnutils.filter(spacesLayout[spaceUUID], function(spaceId)
      return hs.spaces.spaceType(spaceId) == 'user'
    end)

    hs.fnutils.concat(spacesIds, userSpaces or {})
  end)

  return spacesIds
end

local throwToSpace = function(win, spaceIdx)
  local spacesIds = getSpacesIdsTable()
  local spaceId = spacesIds[spaceIdx]

  if not spaceId then
    return false
  end

  hs.spaces.moveWindowToSpace(win:id(), spaceId)
end

local pushWindowNextScreen = function(win)
  local win = hs.window.frontmostWindow()

  if not win then
    return
  end

  local noResize = true
  local ensureInScreenBounds = true

  win:moveToScreen(win:screen():next(), noResize, ensureInScreenBounds)
end

local pushWindowPrevScreen = function(win)
  local win = hs.window.frontmostWindow()

  if not win then
    return
  end

  local noResize = true
  local ensureInScreenBounds = true

  win:moveToScreen(win:screen():previous(), noResize, ensureInScreenBounds)
end

local ONLY_FRONTMOST = true
local STRICT_ANGLE   = true

-- works for windows and screens!
local focusAndHighlight = function(cmd)
  local focusedWindow     = hs.window.focusedWindow()
  local focusedScreen     = activeScreen()

  local winCmd            = 'windowsTo' .. capitalize(cmd)
  local screenCmd         = 'to' .. capitalize(cmd)

  local windowsToFocus    = cache.windowFilter[winCmd](cache.windowFilter, focusedWindow, ONLY_FRONTMOST, STRICT_ANGLE)
  local screenInDirection = focusedScreen[screenCmd](focusedScreen)
  local filterWindows     = cache.windowFilter:getWindows()

  local windowOnSameOrNextScreen = function(testWin, currentScreen, nextScreen)
    return testWin:screen():id() == currentScreen:id() or testWin:screen():id() == nextScreen:id()
  end

  -- focus window if we have any, and it's on nearest or current screen (don't jump over empty screens)
  if windowsToFocus and #windowsToFocus > 0 and windowOnSameOrNextScreen(windowsToFocus[1], focusedScreen, screenInDirection) then
    forceFocus(windowsToFocus[1])
  -- focus screen in given direction if exists
  elseif screenInDirection then
    focusScreen(screenInDirection)
  -- focus first window if there are any
  elseif #filterWindows > 0 then
    forceFocus(filterWindows[1])
  -- finally focus the screen if nothing else works
  else
    focusScreen(focusedScreen)
  end
end

module.start = function()
  cache.windowFilter = hs.window.filter.new()
    :setCurrentSpace(true)
    :setDefaultFilter()
    :keepActive()

  local bind = function(key, fn)
    hs.hotkey.bind({ 'ctrl', 'shift' }, key, fn, nil, fn)
  end

  bind('z', function() pressWindowMenuItem('Fill') end)
  bind('c', function() pressWindowMenuItem('Center') end)
  bind('u', function() pressWindowMoveResizeMenuItem('Return to Previous Size') end)

  bind('s', function()
    local screen = activeScreen()
    local windows = cache.windowFilter:getWindows()
    local windowsOnScreen = hs.fnutils.filter(windows, function(win)
      return win:screen():id() == screen:id()
    end)

    if (#windowsOnScreen == 0) then
      return
    elseif (#windowsOnScreen == 1) then
      pressWindowMoveResizeMenuItem('Right')
    else
      -- pressWindowMoveResizeMenuItem('Left & Right')
      pressWindowMoveResizeMenuItem('Right & Left')
    end
  end)

  bind("[", function() pushWindowNextScreen() end)
  bind("]", function() pushWindowPrevScreen() end)

  hs.fnutils.each({
    { key = 'h', cmd = 'west'  },
    { key = 'j', cmd = 'south' },
    { key = 'k', cmd = 'north' },
    { key = 'l', cmd = 'east'  }
  }, function(object)
    bind(object.key, function()
      focusAndHighlight(object.cmd)
    end)
  end)

  -- throw window to space (and move)
  for n = 0, 9 do
    local idx = tostring(n)

    -- important: use this with onKeyReleased, not onKeyPressed
    hs.hotkey.bind({ 'ctrl', 'shift' }, idx, nil, function()
      local win = hs.window.focusedWindow()

      if win then
        throwToSpace(win, n == 0 and 10 or n)
      end

      hs.eventtap.keyStroke({ 'ctrl' }, idx)
    end)
  end
end

module.stop = function()
end

return module
