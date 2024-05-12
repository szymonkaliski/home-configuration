local activeScreen    = require('ext.screen').activeScreen
local capitalize      = require('ext.utils').capitalize
local focusScreen     = require('ext.screen').focusScreen
local forceFocus      = require('ext.window').forceFocus
local highlightWindow = require('ext.drawing').highlightWindow

local cache  = {}
local module = { cache = cache }

local ONLY_FRONTMOST = true
local STRICT_ANGLE   = true

-- works for windows and screens!
local focusAndHighlight = function(cmd)
  local focusedWindow     = hs.window.focusedWindow()
  local focusedScreen     = activeScreen()

  local winCmd            = 'windowsTo' .. capitalize(cmd)
  local screenCmd         = 'to' .. capitalize(cmd)

  local windowsToFocus    = cache.focusFilter[winCmd](cache.focusFilter, focusedWindow, ONLY_FRONTMOST, STRICT_ANGLE)
  local screenInDirection = focusedScreen[screenCmd](focusedScreen)
  local filterWindows     = cache.focusFilter:getWindows()

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

local cycleWindows = function(direction)
  local win = hs.window.focusedWindow()
  local windows = cache.focusFilter:getWindows(hs.window.filter.sortByCreated)

  if #windows == 0 then
    focusScreen()
  elseif #windows == 1 then
    -- if we have only one window - focus it
    forceFocus(windows[1])
  elseif #windows > 1 then
    -- check if one of them is active
    local activeWindowIndex = hs.fnutils.indexOf(windows, win)

    if activeWindowIndex then
      if direction == "next" then
        activeWindowIndex = activeWindowIndex + 1
        if activeWindowIndex > #windows then activeWindowIndex = 1 end
      else
        activeWindowIndex = activeWindowIndex - 1
        if activeWindowIndex < 1 then activeWindowIndex = #windows end
      end

      forceFocus(windows[activeWindowIndex])
    else
      -- otherwise focus first one
      forceFocus(windows[1])
    end
  end

  -- higlight when done
  highlightWindow()
end

module.start = function()
  local bind = function(key, fn)
    hs.hotkey.bind({ 'ctrl', 'alt' }, key, fn, nil, fn)
  end

  cache.focusFilter = hs.window.filter.new()
    :setCurrentSpace(true)
    :setDefaultFilter()
    :keepActive()

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

  -- cycle between windows on current screen, useful in tiling monocle mode
  bind(']', function() cycleWindows('next') end)
  bind('[', function() cycleWindows('prev') end)
end

module.stop = function()
end

return module;
