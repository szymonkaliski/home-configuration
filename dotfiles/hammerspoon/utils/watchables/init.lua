local status            = hs.watchable.new('status')
local log               = hs.logger.new('watchables', 'debug')
local isDarkModeEnabled = require('ext.system').isDarkModeEnabled
local debounce          = require('ext.utils').debounce

local cache  = { status = status }
local module = { cache = cache }

local STUDIO_DISPLAY_UUID = '464307F2-7664-40E9-8705-3B2EB3451EF6'

local updateBattery = function()
  local burnRate = hs.battery.designCapacity() / math.abs(hs.battery.amperage())

  status.battery = {
    isCharging       = hs.battery.isCharging(),
    isCharged        = hs.battery.isCharged(),
    percentage       = hs.battery.percentage(),
    powerSource      = hs.battery.powerSource(),
    amperage         = hs.battery.amperage(),
    wattage          = hs.battery.watts(),
    timeRemaining    = hs.battery.timeRemaining(),
    timeToFullCharge = hs.battery.timeToFullCharge(),
    burnRate         = burnRate,
  }
end

local updateScreen = function()
  local screens = hs.screen.allScreens()

  status.connectedScreens         = #screens
  status.connectedScreenIds       = hs.fnutils.map(screens, function(screen) return screen:id() end)
  status.connectedScreenNames     = hs.fnutils.map(screens, function(screen) return screen:name() end)
  status.isLaptopScreenConnected  = hs.screen.findByName('Color LCD') ~= nil
  status.isStudioDisplayConnected = hs.fnutils.find(screens, function(s) return s:getUUID() == STUDIO_DISPLAY_UUID end) ~= nil

  log.d('updated screens:', hs.inspect(status.connectedScreenNames))
end

local updateWiFi = function()
  status.currentNetwork = hs.wifi.currentNetwork()

  log.d('updated wifi:', status.currentNetwork)
end

local updateSleep = function(event)
  status.sleepEvent = event

  log.d('updated sleep:', status.sleepEvent)
end

local updateUSB = function()
  status.isErgodoxAttached = hs.fnutils.find(hs.usb.attachedDevices(), function(device)
    return device.productName == 'ErgoDox EZ'
  end) ~= nil

  log.d('updated ergodox:', status.isErgodoxAttached)
end

local updateTheme = function()
  status.theme = isDarkModeEnabled() and "dark" or "light"

  log.d('updated theme:', status.theme)
end

module.start = function()
  -- start watchers
  cache.watchers = {
    -- sleep   = hs.caffeinate.watcher.new(updateSleep),
    -- wifi    = hs.wifi.watcher.new(updateWiFi),

    battery = hs.battery.watcher.new(updateBattery),
    screen  = hs.screen.watcher.new(updateScreen),
    theme   = hs.distributednotifications.new(updateTheme, "AppleInterfaceThemeChangedNotification"),
    usb     = hs.usb.watcher.new(debounce(updateUSB, 3)),
  }

  hs.fnutils.each(cache.watchers, function(watcher)
    watcher:start()
  end)

  updateBattery()
  updateScreen()
  updateTheme()
  updateUSB()
end

module.stop = function()
  hs.fnutils.each(cache.watchers, function(watcher)
    watcher:stop()
  end)
end

return module
