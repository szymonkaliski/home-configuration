local loggers      = {}
local runningTasks = {}
local module       = { loggers = loggers, runningTasks = runningTasks }

-- runs a script through a login zsh so it inherits the env set up in
-- ~/.zprofile (PATH etc.); Hammerspoon is launched by launchd without it
--
-- logs stdout/stderr and pops a notification if the script exits non-zero
module.runScript = function(path, arguments, onSuccess)
  local name    = path:match('[^/]+$')
  local logger  = loggers[name] or hs.logger.new(name, 'info')
  loggers[name] = logger

  local args = { '-l', '-c', 'exec "$0" "$@"', path }
  for _, arg in ipairs(arguments) do
    table.insert(args, arg)
  end

  -- declared before the callback so it captures the local, not a global;
  -- runningTasks holds a strong reference until the callback fires, otherwise
  -- the GC can collect and kill an in-flight task
  local task

  task = hs.task.new('/bin/zsh', function(exitCode, stdOut, stdErr)
    runningTasks[task] = nil

    if stdOut and #stdOut > 0 then logger.i(stdOut) end
    if stdErr and #stdErr > 0 then logger.w(stdErr) end

    if exitCode == 0 then
      logger.i('done: ' .. table.concat(arguments, ' '))
      if onSuccess then onSuccess(stdOut) end
      return
    end

    logger.e('failed with exit code ' .. exitCode .. ': ' .. table.concat(arguments, ' '))

    hs.notify.new({
      title    = name .. ' failed',
      subTitle = 'Look into Hammerspoon Console for more info'
    }):send()
  end, args)

  runningTasks[task] = true
  task:start()

  return task
end

return module
