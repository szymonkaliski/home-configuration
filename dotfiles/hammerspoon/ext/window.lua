local activeScreen    = require('ext.screen').activeScreen
local capitalize      = require('ext.utils').capitalize
local focusScreen     = require('ext.screen').focusScreen
local highlightWindow = require('ext.drawing').highlightWindow

local cache = {
  windowPositions = hs.settings.get('windowPositions') or {},
  windowFilter = hs.window.filter.new()
    :setCurrentSpace(true)
    :setDefaultFilter()
    :keepActive()
}

local module = { cache = cache }

module.forceFocus = function(win)
  -- this flickers
  -- win:application():activate()

  win:becomeMain()
  win:raise():focus()
  highlightWindow()
end

-- show hints with highlight
module.windowHints = function()
  hs.hints.windowHints(hs.window.visibleWindows(), highlightWindow)
end

-- save and restore window positions
module.persistPosition = function(win, option)
  local windowPositions = cache.windowPositions

  -- store position into hs.settings
  if win == 'store' or option == 'store' then
    hs.settings.set('windowPositions', windowPositions)
    return
  end

  -- otherwise run the logic
  local application = win:application()
  local appId       = application:bundleID() or application:name()
  local frame       = win:frame()
  local index       = windowPositions[appId] and windowPositions[appId].index or nil
  local frames      = windowPositions[appId] and windowPositions[appId].frames or {}

  -- check if given frame differs frome last one in array
  local framesDiffer = function(testFrame, testFrames)
    return testFrame and (#testFrames == 0 or not testFrame:equals(testFrames[#testFrames]))
  end

  -- remove first element if we hit history limit (adjusting index if needed)
  if #frames > math.max(1, config.window.historyLimit) then
    table.remove(frames, 1)
    index = index > #frames and #frames or math.max(index - 1, 1)
  end

  -- append window position to a table, only if it's a new frame
  if option == 'save' and framesDiffer(frame, frames) then
    table.insert(frames, frame.table)
    index = #frames
  end

  -- undo window position
  if option == 'undo' and index ~= nil then
    -- if we are at the last index
    -- (or more, which shouldn't happen?)
    if index >= #frames then
      if framesDiffer(frame, frames) then
        -- and current frame differs from last one - save it
        table.insert(frames, frame.table)
      else
        -- otherwise frames are the same, so get the previous one
        index = math.max(index - 1, 1)
      end
    end

    win:setFrame(frames[index])
    index = math.max(index - 1, 1)
  end

  -- redo window position
  if option == 'redo' and index ~= nil then
    index = math.min(#frames, index + 1)
    win:setFrame(frames[index])
  end

  -- update cached window positions object
  cache.windowPositions[appId] = {
    index  = index,
    frames = frames
  }
end

module.windowMetadata = function(win)
  if not win then return nil end

  local app = win:application()
  if not app then return nil end

  local name  = app:name()
  local title = win:title()
  local meta  = ''

  if name == 'Google Chrome' then
    if string.match(title, 'Find in page') then
      title = ''
      meta = ''
    elseif string.match(title, '(Incognito)') then
      -- don't log incognito windows
      title = '(Incognito)'
    else
      -- log URLs
      local _, result = hs.applescript.applescript([[
        tell application "Google Chrome" to get URL of active tab of first window
      ]])

      if result ~= nil then
        meta = result
      end
    end
  elseif name == 'Safari' then
    if string.match(title, 'Private Browsing') then
      -- don't log incognito windows
      title = 'Private Browsing'
    else
      -- log URLs
      local _, metaResult = hs.applescript.applescript([[
        tell application "Safari" to get URL of current tab of first window
      ]])

      if metaResult ~= nil then
        meta = metaResult
      end
    end
  elseif name == 'Finder' then
    -- log paths
    local _, result = hs.applescript.applescript([[
      tell application "Finder" to get POSIX path of (target of front Finder window as text)
    ]])

    if result ~= nil then
      meta = result
    end
  else
    -- default to trying to grab AXDocument from window
    -- works for Preview, Keynote, Pages, and most of document-based macOS apps
    local document = hs.axuielement.windowElement(win):attributeValue('AXDocument')

    if document ~= nil then
      meta = document
    end
  end

  return title, meta
end

module.cycleWindowFocus = function(direction)
  local win = hs.window.focusedWindow()
  local windows = cache.windowFilter:getWindows(hs.window.filter.sortByCreated)

  if #windows == 0 then
    focusScreen()
  elseif #windows == 1 then
    -- if we have only one window - focus it
    module.forceFocus(windows[1])
  elseif #windows > 1 then
    -- check if one of them is active
    local activeWindowIndex = hs.fnutils.indexOf(windows, win)

    if activeWindowIndex then
      if direction == "prev" then
        activeWindowIndex = activeWindowIndex - 1
        if activeWindowIndex < 1 then activeWindowIndex = #windows end
      else
        activeWindowIndex = activeWindowIndex + 1
        if activeWindowIndex > #windows then activeWindowIndex = 1 end
      end

      module.forceFocus(windows[activeWindowIndex])
    else
      -- otherwise focus first one
      module.forceFocus(windows[1])
    end
  end

  -- higlight when done
  highlightWindow()
end

-- works for windows and screens!
module.focusAndHighlight = function(cmd)
  local ONLY_FRONTMOST = true
  local STRICT_ANGLE   = true

  local focusedWindow  = hs.window.focusedWindow()
  local focusedScreen  = activeScreen()

  local winCmd         = 'windowsTo' .. capitalize(cmd)
  local screenCmd      = 'to' .. capitalize(cmd)

  local windowsToFocus    = cache.windowFilter[winCmd](cache.windowFilter, focusedWindow, ONLY_FRONTMOST, STRICT_ANGLE)
  local screenInDirection = focusedScreen[screenCmd](focusedScreen)
  local filterWindows     = cache.windowFilter:getWindows()

  local windowOnSameOrNextScreen = function(testWin, currentScreen, nextScreen)
    return testWin:screen():id() == currentScreen:id() or testWin:screen():id() == nextScreen:id()
  end

  -- focus window if we have any, and it's on nearest or current screen (don't jump over empty screens)
  if windowsToFocus and #windowsToFocus > 0 and windowOnSameOrNextScreen(windowsToFocus[1], focusedScreen, screenInDirection) then
    module.forceFocus(windowsToFocus[1])
  -- focus screen in given direction if exists
  elseif screenInDirection then
    focusScreen(screenInDirection)
  -- focus first window if there are any
  elseif #filterWindows > 0 then
    module.forceFocus(filterWindows[1])
  -- finally focus the screen if nothing else works
  else
    focusScreen(focusedScreen)
  end
end

return module
