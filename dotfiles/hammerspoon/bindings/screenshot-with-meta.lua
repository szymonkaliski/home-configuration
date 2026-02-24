local windowMetadata = require('ext.window').windowMetadata
local log            = hs.logger.new("screenshot-with-meta", "debug")

local cache  = {}
local module = { cache = cache }

local ADD_OCR_TO_IMAGE_PATH       = os.getenv('HOME') .. '/.bin/add-ocr-to-image'
local ADD_WHEREFROMS_TO_IMAGE_PATH = os.getenv('HOME') .. '/.bin/add-wherefroms-to-image'
local SCREENSHOT_PATH              = os.getenv('HOME') .. '/Library/CloudStorage/Dropbox/Screenshots/'

local SCREENCAPTURE_PATH           = '/usr/sbin/screencapture'

local genScreenshotPath = function()
  local screenshotName = os.date('Screenshot %Y-%m-%d at %H.%M.%S.png')
  local fileName       = SCREENSHOT_PATH .. screenshotName
  return fileName
end

local sendNotification = function(fileName)
  local revealFile = function()
    os.execute('open -R "' .. fileName .. '"')
  end

  hs.notify.new(revealFile, {
    title        = 'Screenshot',
    subTitle     = 'Captured!',
    contentImage = fileName
  }):send()
end

local addMetaToScreenshot = function(win, fileName)
  local title, meta = windowMetadata(win)

  if meta ~= nil and meta ~= '' then
    cache['wherefroms:' .. fileName] = hs.task.new(
      ADD_WHEREFROMS_TO_IMAGE_PATH,
      function(exitCode, stdOut, stdErr)
        cache['wherefroms:' .. fileName] = nil

        if stdOut and #stdOut > 0 then log.i(stdOut) end
        if stdErr and #stdErr > 0 then log.w(stdErr) end

        if exitCode == 0 then
          log.i("WhereFroms done: " .. fileName)
          return
        end

        hs.notify.new({
          title    = "Screenshot WhereFroms failed",
          subTitle = "Look into Hammerspoon Console for more info"
        }):send()
      end,
      { fileName, meta }
    )
    cache['wherefroms:' .. fileName]:start()
  end

  -- adds OCR to the image; --url prepends the source URL to kMDItemFinderComment
  -- because Dropbox only syncs that xattr to Linux (not kMDItemWhereFroms)
  cache[fileName] = hs.task.new(
    ADD_OCR_TO_IMAGE_PATH,
    function(exitCode, stdOut, stdErr)
      cache[fileName] = nil

      if stdOut and #stdOut > 0 then log.i(stdOut) end
      if stdErr and #stdErr > 0 then log.w(stdErr) end

      if exitCode == 0 then
        log.i("OCR done: " .. fileName)
        return
      end

      hs.notify.new({
        title    = "Screenshot OCR failed",
        subTitle = "Look into Hammerspoon Console for more info"
      }):send()
    end,
    (meta ~= nil and meta ~= '') and { '--url', meta, fileName } or { fileName }
  )
  cache[fileName]:start()
end

-- screencapture can exit before the file is fully flushed to disk
local processScreenshot = function(focusedWindow, fileName, attempt)
  attempt = attempt or 1

  local image = hs.image.imageFromPath(fileName)

  if image then
    log.i("processing screenshot: " .. fileName)
    hs.pasteboard.writeObjects(image)
    sendNotification(fileName)
    addMetaToScreenshot(focusedWindow, fileName)
    return
  end

  if attempt < 5 then
    log.w("file not ready (attempt " .. attempt .. "): " .. fileName)
    hs.timer.doAfter(0.5, function()
      processScreenshot(focusedWindow, fileName, attempt + 1)
    end)
  else
    log.e("file not ready after 5 attempts: " .. fileName)
    hs.notify.new({
      title    = "Screenshot",
      subTitle = "Failed to process screenshot"
    }):send()
  end
end

module.start = function()
  -- capture the main screen
  -- TODO: capture screen with mouse, not sure how to calculate this for screencapture though
  hs.hotkey.bind({ 'cmd', 'shift' }, '3', function()
    local focusedWindow = hs.window.frontmostWindow()
    local fileName      = genScreenshotPath()

    cache[fileName] = hs.task.new(
      SCREENCAPTURE_PATH,
      function() cache[fileName] = nil; processScreenshot(focusedWindow, fileName) end,
      { "-D1", fileName }
    )
    cache[fileName]:start()
  end)

  -- normal picker, with additional metadata for focused window
  hs.hotkey.bind({ 'cmd', 'shift' }, '4', function()
    local focusedWindow = hs.window.frontmostWindow()
    local fileName      = genScreenshotPath()

    cache[fileName] = hs.task.new(
      SCREENCAPTURE_PATH,
      function() cache[fileName] = nil; processScreenshot(focusedWindow, fileName) end,
      { "-i", fileName }
    )
    cache[fileName]:start()
  end)

  -- fullscreen window screenshot
  --
  -- not using `hs.window.focusedWindow():snapshot():saveToFile(fileName)` because there's no window shadow then
  -- not using `-l` flag for `screencapture` since the window id it requires is _not_ the window id that Hammerspoon tracks
  --
  -- mouse click timings are fairly arbitrary, but seem to work
  hs.hotkey.bind({ 'cmd', 'shift' }, '6', function()
    local focusedWindow = hs.window.frontmostWindow()

    if not focusedWindow then
      return
    end

    local fileName      = genScreenshotPath()
    local mousePosition = hs.mouse.absolutePosition()
    local windowCenter  = hs.geometry.getcenter(focusedWindow:frame())

    -- center mouse in the window frame
    hs.mouse.absolutePosition(windowCenter)

    -- after we start the task above, the screencapture is running until the mouse click happens,
    -- that's why the `addMetaToScreenshot` is inside the callback when screencapture terminates,
    -- it will run _after_ the code which simulates mouse click:

    cache[fileName] = hs.task.new(
      SCREENCAPTURE_PATH,
      function() cache[fileName] = nil; processScreenshot(focusedWindow, fileName) end,
      { "-w", fileName }
    )
    cache[fileName]:start()

    -- click
    hs.timer.usleep(100000)
    hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, windowCenter):post()
    hs.timer.usleep(2000)
    hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, windowCenter):post()

    -- restore original mouse position
    hs.mouse.absolutePosition(mousePosition)
  end)
end

module.stop = function()
end

return module
