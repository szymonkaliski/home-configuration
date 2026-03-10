local activeScreen      = require('ext.screen').activeScreen
local cycleWindowFocus  = require('ext.window').cycleWindowFocus
local focusAndHighlight = require('ext.window').focusAndHighlight

local ANIMATION_DURATION = 0.2
local MARGIN = 8

local cache  = {}
local module = { cache = cache }

local selectMenuItem = function(path)
  local app = hs.application.frontmostApplication()
  if not app then return false end
  return app:selectMenuItem(path)
end

local previousFrames = {}

local setFrameWithUndo = function(win, frame)
  previousFrames[win:id()] = win:frame()
  win:setFrame(frame, ANIMATION_DURATION)
end

local snapHalf = function(win, side)
  local screenFrame = win:screen():frame()
  local x = side == 'left'
    and screenFrame.x + MARGIN
    or  screenFrame.x + screenFrame.w / 2 + MARGIN / 2

  setFrameWithUndo(win, hs.geometry.rect(
    x,
    screenFrame.y + MARGIN,
    screenFrame.w / 2 - MARGIN * 1.5,
    screenFrame.h - MARGIN * 2
  ))
end

local windowIsOnRight = function(win)
  local screenFrame = win:screen():frame()
  local winFrame = win:frame()
  local screenCenter = screenFrame.x + screenFrame.w / 2
  local winCenter = winFrame.x + winFrame.w / 2

  return winCenter > screenCenter
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

module.start = function()
  cache.windowFilter = hs.window.filter.new()
    :setCurrentSpace(true)
    :setDefaultFilter()
    :keepActive()

  local bind = function(key, fn)
    hs.hotkey.bind({ 'ctrl', 'shift' }, key, fn, nil, fn)
  end

  bind('z', function()
    local success = selectMenuItem({ 'Window', 'Fill' })
    if not success then
      local win = hs.window.frontmostWindow()
      if not win then return end

      local screenFrame = win:screen():frame()

      setFrameWithUndo(win, hs.geometry.rect(
        screenFrame.x + MARGIN,
        screenFrame.y + MARGIN,
        screenFrame.w - MARGIN * 2,
        screenFrame.h - MARGIN * 2
      ))
    end
  end)

  bind('c', function()
    local success = selectMenuItem({ 'Window', 'Center' })
    if not success then
      local win = hs.window.frontmostWindow()
      if not win then return end

      local screenFrame = win:screen():frame()
      local winFrame = win:frame()

      setFrameWithUndo(win, hs.geometry.rect(
        screenFrame.x + (screenFrame.w - winFrame.w) / 2,
        screenFrame.y + (screenFrame.h - winFrame.h) / 2,
        winFrame.w,
        winFrame.h
      ))
    end
  end)

  bind('u', function()
    local success = selectMenuItem({ 'Window', 'Move & Resize', 'Return to Previous Size' })
    if not success then
      local win = hs.window.frontmostWindow()
      if not win then return end

      local prevFrame = previousFrames[win:id()]

      if prevFrame then
        win:setFrame(prevFrame, ANIMATION_DURATION)
        previousFrames[win:id()] = nil
      end
    end
  end)

  bind('s', function()
    local screen = activeScreen()
    local windows = cache.windowFilter:getWindows()
    local windowsOnScreen = hs.fnutils.filter(windows, function(win)
      return win:screen():id() == screen:id()
    end)

    if (#windowsOnScreen == 0) then
      return
    end

    local win = hs.window.frontmostWindow()
    if not win then return end

    local isOnRight = windowIsOnRight(win)

    if (#windowsOnScreen == 1) then
      local menuItem = isOnRight and 'Left' or 'Right'
      local success = selectMenuItem({ 'Window', 'Move & Resize', menuItem })

      if not success then
        snapHalf(win, isOnRight and 'left' or 'right')
      end
    else
      local menuItem = isOnRight and 'Left & Right' or 'Right & Left'
      local success = selectMenuItem({ 'Window', 'Move & Resize', menuItem })

      if not success then
        snapHalf(win, isOnRight and 'left' or 'right')
      end
    end
  end)

  bind('[', function() pushWindowPrevScreen() end)
  bind(']', function() pushWindowNextScreen() end)

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

  -- alt-tab as an alternative to cmd-tab to cycle through windows instead of apps
  hs.hotkey.bind({ 'alt' }, 'tab', function()
    cycleWindowFocus('next')
  end)
  hs.hotkey.bind({ 'alt', 'shift' }, 'tab', function()
    cycleWindowFocus('prev')
  end)
end

module.stop = function()
end

return module
