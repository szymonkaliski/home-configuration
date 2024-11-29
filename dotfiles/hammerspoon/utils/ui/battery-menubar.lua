local cache  = {}
local module = { cache = cache }

local STYLE = {
  font = {
    name = hs.styledtext.defaultFonts.menuBar.name,
    size = 13.0
  },
  baselineOffset = 0.0
}

local setMenubarText = function(text)
  cache.menuItem:setTitle(hs.styledtext.new(text, STYLE))
end

local setMenubarMenu = function(percentage)
  cache.menuItem:setMenu({
    {
      title = 'Battery',
      disabled = true
    },
    {
      title = 'Charge: ' .. math.floor(percentage) .. '%'
    }
  })
end

local stringifyMinutes = function(minutes)
  local hours   = math.floor(minutes / 60)
  local minutes = minutes % 60

  return string.format('%02d:%02d', hours, minutes)
end

local batteryWatcher = function(_, _, _, _, battery)
  -- always update the menubar menu
  setMenubarMenu(battery.percentage)

  -- fully charged, leave menu item in the menubar so it doesn't move
  if battery.isCharged then
    setMenubarText("ϟ")
    return
  end

  -- we're charging right now
  if battery.isCharging then
    if battery.timeToFullCharge < 0 then
      -- still calculating, show percentage
      setMenubarText('⇡ ' .. math.floor(battery.percentage) .. '%')
      return
    end

    -- display leftover charging time
    setMenubarText('⇡ ' .. stringifyMinutes(battery.timeToFullCharge))
    return
  end

  -- we're discarchaging
  if battery.timeRemaining < 0 then
    -- still calculating, show percentage
    setMenubarText('⇣ ' .. math.floor(battery.percentage) .. '%')
    return
  end

  -- display used watts and leftover time when we have it
  local wattage = battery.wattage * -1 -- we know we're discharging!
  local time = stringifyMinutes(battery.timeRemaining)

  setMenubarText(string.format('%.1fW ⇣ %s', wattage, time))
end

module.start = function()
  cache.menuItem = hs.menubar.new(true, 'battery-menubar')
  cache.watcher  = hs.watchable.watch('status.battery', batteryWatcher)
end

module.stop = function()
  cache.watcher:release()
end

return module
