local cycleWindowFocus  = require('ext.window').cycleWindowFocus
local focusAndHighlight = require('ext.window').focusAndHighlight

local module = {}

module.start = function()
  local bind = function(key, fn)
    hs.hotkey.bind({ 'ctrl', 'alt' }, key, fn, nil, fn)
  end

  hs.fnutils.each({
    { key = 'h', cmd = 'west'  },
    { key = 'j', cmd = 'south' },
    { key = 'k', cmd = 'north' },
    { key = 'l', cmd = 'east'  }
  }, function(object)
    bind(object.key, function()
      focusAndHighlight(object.cmd)
    end)
  end)

  -- cycle between windows on current screen, useful in tiling monocle mode
  bind(']', function() cycleWindowFocus('next') end)
  bind('[', function() cycleWindowFocus('prev') end)
end

module.stop = function()
end

return module;
