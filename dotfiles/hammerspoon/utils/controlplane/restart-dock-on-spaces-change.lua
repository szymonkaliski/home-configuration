-- the Dock maps ctrl-N ("Switch to Desktop N") to space ids once, at launch
-- unplugging/replugging a display merges and re-splits spaces with new ids,
-- the Dock keeps the stale map and ctrl-N stops working for those desktops
-- restarting the Dock rebuilds the map, spaces and windows survive it
local log = hs.logger.new('restart-dock', 'debug')

-- spaces re-split a while after the screen watcher fires, so wait a bit
local SETTLE_SECONDS = 5

local cache = {}
local module = { cache = cache }

local userSpaceIds = function()
  local ids = {}

  for _, spaceIds in pairs(hs.spaces.allSpaces() or {}) do
    for _, spaceId in ipairs(spaceIds) do
      if hs.spaces.spaceType(spaceId) == 'user' then
        table.insert(ids, spaceId)
      end
    end
  end

  table.sort(ids)

  return table.concat(ids, ',')
end

module.restartDockIfSpacesChanged = function()
  local currentIds = userSpaceIds()

  if currentIds == cache.spaceIds then
    log.d('spaces unchanged:', currentIds)
    return false
  end

  log.d('spaces changed from', cache.spaceIds, 'to', currentIds, '- restarting Dock')
  cache.spaceIds = currentIds

  hs.execute('killall Dock')

  return true
end

local screensWatcher = function(_, _, _, prev)
  -- first callback is the initial value set on Hammerspoon start
  if prev == nil then
    return
  end

  if cache.settleTimer then
    cache.settleTimer:stop()
  end

  cache.settleTimer = hs.timer.doAfter(SETTLE_SECONDS, module.restartDockIfSpacesChanged)
end

module.start = function()
  cache.spaceIds = userSpaceIds()
  cache.watcherScreens = hs.watchable.watch('status.connectedScreenIds', screensWatcher)
end

module.stop = function()
  if cache.settleTimer then
    cache.settleTimer:stop()
  end

  cache.watcherScreens:release()
end

return module
