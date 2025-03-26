local activateFrontmost = require('ext.application').activateFrontmost
local capitalize        = require('ext.utils').capitalize
local template          = require('ext.template')

local module = {}

-- show notification center
-- NOTE: you can do that from Settings > Keyboard > Mission Control
module.toggleNotificationCenter = function()
  hs.applescript.applescript([[
    tell application "System Events" to tell process "SystemUIServer"
      click menu bar item "Notification Center" of menu bar 2
    end tell
  ]])
end

module.toggleWiFi = function()
  local newStatus = not hs.wifi.interfaceDetails().power

  hs.wifi.setPower(newStatus)

  local imagePath = os.getenv('HOME') .. '/.hammerspoon/assets/airport.png'

  hs.notify.new({
    title        = 'Wi-Fi',
    subTitle     = 'Power: ' .. (newStatus and 'On' or 'Off'),
    contentImage = imagePath
  }):send()
end

module.toggleConsole = function()
  hs.toggleConsole()
  activateFrontmost()
end

module.displaySleep = function()
  hs.task.new('/usr/bin/pmset', nil, { 'displaysleepnow' }):start()
end

module.isDarkModeEnabled = function()
  local _, res = hs.osascript.javascript([[
    Application("System Events").appearancePreferences.darkMode()
  ]])

  return res == true -- getting nil here sometimes
end

module.setTheme = function(theme)
  -- I used to set Alfred theme here too, but that's not necessary
  -- Alfred remembers which theme was set when the system was in the light or dark mode
  hs.osascript.javascript(template([[
    var systemEvents = Application("System Events");

    ObjC.import("stdlib");

    systemEvents.appearancePreferences.darkMode = {DARK_MODE};
  ]], {
    DARK_MODE = theme == 'dark' and 'true' or 'false'
  }))
end

module.toggleTheme = function()
  local isDarkModeEnabled = module.isDarkModeEnabled()

  module.setTheme(isDarkModeEnabled and 'light' or 'dark')

  local imagePath = os.getenv('HOME') .. '/.hammerspoon/assets/theme.png'

  hs.notify.new({
    title        = 'Theme',
    subTitle     = 'Switched to: ' .. (isDarkModeEnabled and 'Light' or 'Dark'),
    contentImage = imagePath
  }):send()
end

module.restartHammerspoon = function()
  hs.reload()
end

return module

