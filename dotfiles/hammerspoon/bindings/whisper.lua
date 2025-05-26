local log = hs.logger.new("whisper", "debug")

local cache  = { task = nil, menuItem = nil }
local module = { cache = cache }

local MIC_ICON = hs.image.imageFromName("NSTouchBarAudioInputTemplate")
local WHISPER_PATH = os.getenv('HOME') .. '/.bin/whisper'

module.start = function()
  hs.hotkey.bind({ 'ctrl', 'alt', 'cmd' }, 'd', function()
    if not cache.task then
      cache.menuItem = hs.menubar.new()
        :setIcon(MIC_ICON)

      cache.task = hs.task.new(
        WHISPER_PATH,
        function(exitCode, stdOut, stdErr)
          log.i(exitCode)
          log.i(stdOut)
          log.i(stdErr)

          cache.task = nil
          cache.menuItem:delete()
        end
      ):start()
    else
      cache.task:interrupt()
    end
  end)
end

module.stop = function()
  if cache.menuItem then
    cache.menuItem:delete()
  end

  if cache.task then
    cache.task:interrupt()
    cache.task = nil
  end
end

return module
