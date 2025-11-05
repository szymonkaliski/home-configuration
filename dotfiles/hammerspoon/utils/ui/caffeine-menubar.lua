local cache  = {}
local module = { cache = cache }

local ICON_PATH = os.getenv('HOME') .. '/.hammerspoon/assets/caffeine-3-on.png'
-- created dynamically to have "greayed out" color
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

local updateCaffeine

local generateCaffeineMenu = function(options)
  return {
    {
      title = options.statusText,
      disabled = true
    },
    {
      title = options.subStatusText,
      fn = function()
        updateCaffeine(options.preventDisplaySleep)
      end
    },
    {
      title = '-',
    },
    {
      title = 'Sleep Now',
      fn = function()
        updateCaffeine(false)
        hs.caffeinate.systemSleep()
      end
    }
  }
end

local updateMenuItem = function()
  local isDisplaySleepPrevented = hs.caffeinate.get('displayIdle')

  if isDisplaySleepPrevented then
    cache.menuItem:setIcon(ICON_ON)
    cache.currentMenu = generateCaffeineMenu({
      statusText          = 'Sleep: Disabled',
      subStatusText       = 'Enable Sleep',
      preventDisplaySleep = false
    })
  else
    cache.menuItem:setIcon(ICON_OFF)
    cache.currentMenu = generateCaffeineMenu({
      statusText          = 'Sleep: Enabled',
      subStatusText       = 'Disable Sleep',
      preventDisplaySleep = true
    })
  end
end

updateCaffeine = function(newStatus)
  if newStatus ~= nil then
    cache.displayIdle = newStatus
  end

  hs.caffeinate.set('displayIdle', cache.displayIdle)
  hs.caffeinate.set('systemIdle', cache.displayIdle)
  hs.caffeinate.set('system', cache.displayIdle)

  updateMenuItem()
end

module.toggleCaffeine = function()
  cache.displayIdle = not hs.caffeinate.get('displayIdle')

  updateCaffeine(cache.displayIdle)
end

module.start = function()
  local BASE_ICON = hs.image.imageFromPath(ICON_PATH):setSize({ w = 20, h = 20 })
  ICON_ON = BASE_ICON
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
      return cache.currentMenu
    end
  end)

  updateCaffeine()
end

module.stop = function()
  hs.settings.set('displayIdle', cache.displayIdle)
end

return module
