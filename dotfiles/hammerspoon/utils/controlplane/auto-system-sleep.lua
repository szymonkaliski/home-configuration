local notify = require('utils.controlplane.notify')
local log    = hs.logger.new('auto-system-sleep', 'debug')

local cache  = {}
local module = { cache = cache }

local studioDisplayWatcher = function(_, _, _, prev, isConnected)
  if prev == isConnected then return end

  hs.caffeinate.set('systemIdle', isConnected)

  if prev ~= nil then
    if isConnected then
      notify('System Sleep Disabled')
    else
      notify('System Sleep Enabled')
    end
  end
end

module.start = function()
  cache.watcherStudioDisplay = hs.watchable.watch('status.isStudioDisplayConnected', studioDisplayWatcher)
end

module.stop = function()
  cache.watcherStudioDisplay:release()
  hs.caffeinate.set('systemIdle', false)
end

return module
