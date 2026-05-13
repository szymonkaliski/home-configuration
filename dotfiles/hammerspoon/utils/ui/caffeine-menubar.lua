local cache  = {}
local module = { cache = cache }

local ICON_PATH = os.getenv('HOME') .. '/.hammerspoon/assets/caffeine-3-on.png'
-- created dynamically to have "greyed out" color
local ICON_ON
local ICON_OFF

local createGreyedIcon = function(img, alpha)
  local size = img:size()
  local canvas = hs.canvas.new({ x = 0, y = 0, w = size.w, h = size.h })

  canvas[1] = {
    type = 'image',
    image = img,
    imageAlpha = alpha
  }

  return canvas:imageFromCanvas()
end

local applyDisplayIdle = function()
  hs.caffeinate.set('displayIdle', cache.displayIdle)
  cache.menuItem:setIcon(cache.displayIdle and ICON_ON or ICON_OFF)
end

local generateMenu = function()
  local displayIdle = hs.caffeinate.get('displayIdle')
  local systemIdle  = hs.caffeinate.get('systemIdle')

  return {
    {
      title    = 'Display Sleep: ' .. (displayIdle and 'Disabled' or 'Enabled'),
      disabled = true
    },
    {
      title = displayIdle and 'Enable Display Sleep' or 'Disable Display Sleep',
      fn    = function()
        cache.displayIdle = not hs.caffeinate.get('displayIdle')
        applyDisplayIdle()
      end
    },
    { title = '-' },
    {
      title    = 'System Sleep: ' .. (systemIdle and 'Disabled' or 'Enabled'),
      disabled = true
    },
    { title = '-' },
    {
      title = 'Sleep Now',
      fn    = function()
        cache.displayIdle = false
        applyDisplayIdle()
        hs.caffeinate.systemSleep()
      end
    }
  }
end

module.toggleCaffeine = function()
  cache.displayIdle = not hs.caffeinate.get('displayIdle')
  applyDisplayIdle()
end

local studioDisplayWatcher = function(_, _, _, prev, isConnected)
  -- when studio display is disconnected, force display sleep back on, overriding any manual toggle
  if prev and not isConnected and cache.displayIdle then
    cache.displayIdle = false
    applyDisplayIdle()
  end
end

module.start = function()
  local BASE_ICON = hs.image.imageFromPath(ICON_PATH):setSize({ w = 20, h = 20 })
  ICON_ON  = BASE_ICON
  ICON_OFF = createGreyedIcon(BASE_ICON, 0.25)

  cache.displayIdle = hs.settings.get('displayIdle') or false
  cache.menuItem    = hs.menubar.new(true, 'caffeine-menubar')

  cache.menuItem:setMenu(function()
    local mods = hs.eventtap.checkKeyboardModifiers()

    -- alt-click toggles the state without showing any menu
    if mods.alt then
      module.toggleCaffeine()
      return {}
    else
      return generateMenu()
    end
  end)

  applyDisplayIdle()

  cache.watcherStudioDisplay = hs.watchable.watch('status.isStudioDisplayConnected', studioDisplayWatcher)
end

module.stop = function()
  cache.watcherStudioDisplay:release()
  hs.settings.set('displayIdle', cache.displayIdle)
end

return module
