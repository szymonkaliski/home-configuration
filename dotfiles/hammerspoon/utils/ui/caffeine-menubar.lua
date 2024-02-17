local cache   = {}
local module  = { cache = cache }

local ICON_OFF = os.getenv('HOME') .. '/.hammerspoon/assets/caffeine-3-off.png'
local ICON_ON  = os.getenv('HOME') .. '/.hammerspoon/assets/caffeine-3-on.png'

local updateCaffeine

local updateMenuItem = function()
  local isDisplaySleepPrevented = hs.caffeinate.get('displayIdle')

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

  if isDisplaySleepPrevented then
    cache.menuItem
      :setMenu(generateCaffeineMenu({
        statusText          = 'Sleep: Disabled',
        subStatusText       = 'Enable Sleep',
        preventDisplaySleep = false
      }))
      :setIcon(ICON_ON)
  else
    cache.menuItem
      :setMenu(generateCaffeineMenu({
        statusText          = 'Sleep: Enabled',
        subStatusText       = 'Disable Sleep',
        preventDisplaySleep = true
      }))
      :setIcon(ICON_OFF)
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
  cache.displayIdle = hs.settings.get('displayIdle') or false
  cache.menuItem    = hs.menubar.new(true, 'caffeine-menubar')

  updateCaffeine()
end

module.stop = function()
  hs.settings.set('displayIdle', cache.displayIdle)
end

return module
