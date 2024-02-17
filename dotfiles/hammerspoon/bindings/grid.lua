local highlightWindow = require('ext.drawing').highlightWindow
local window          = require('ext.window')

local module = {}

-- apply function to a window with optional params, saving it's position for restore
local doWin = function(fn)
  return function()
    local win = hs.window.frontmostWindow()

    if win and not win:isFullScreen() then
      window.persistPosition(win, 'save')
      fn(win)
      highlightWindow(win)
    end
  end
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

local split = function(win, percentage)
  local screen = win:screen()
  local screenGrid = hs.grid.getGrid(screen)
  local currentWindowGrid = hs.grid.get(win)

  local w = math.ceil(screenGrid.w * percentage)

  local leftSplit = hs.geometry(0, 0, w, screenGrid.h)
  local rightSplit = hs.geometry(w, 0, screenGrid.w - w, screenGrid.h)

  if currentWindowGrid == leftSplit then
    hs.grid.set(win, rightSplit, screen)
  else
    hs.grid.set(win, leftSplit, screen)
  end
end

local halfSplit = function(win)
  return split(win, 1 / 2)
end

local thirdSplit = function(win)
  return split(win, 1 / 3)
end

local fourthSplit = function(win)
  return split(win, 1 / 4)
end

module.start = function()
  local bind = function(key, fn)
    hs.hotkey.bind({ 'ctrl', 'shift' }, key, fn, nil, fn)
  end

  hs.fnutils.each({
    { key = 'h', fn = hs.grid.pushWindowLeft       },
    { key = 'j', fn = hs.grid.pushWindowDown       },
    { key = 'k', fn = hs.grid.pushWindowUp         },
    { key = 'l', fn = hs.grid.pushWindowRight      },

    { key = '[', fn = hs.grid.pushWindowNextScreen },
    { key = ']', fn = hs.grid.pushWindowPrevScreen },

    { key = ',', fn = hs.grid.resizeWindowThinner  },
    { key = '.', fn = hs.grid.resizeWindowWider    },

    { key = '=', fn = hs.grid.resizeWindowTaller   },
    { key = '-', fn = hs.grid.resizeWindowShorter  },

    { key = 'z', fn = hs.grid.maximizeWindow       },
    { key = 'c', fn = hs.grid.center               },

    { key = 's', fn = halfSplit                    },
    { key = 't', fn = fourthSplit                  },
  }, function(object)
    bind(object.key, doWin(object.fn))
  end)

  bind('u', function() window.persistPosition(hs.window.frontmostWindow(), 'undo') end)
  bind('r', function() window.persistPosition(hs.window.frontmostWindow(), 'redo') end)

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
