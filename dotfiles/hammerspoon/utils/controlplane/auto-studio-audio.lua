local runScript = require('ext.task').runScript
local status = require('utils.watchables').cache.status
local log = hs.logger.new('auto-studio-audio', 'debug')

local MQTT_HOST = 'minix'
local MQTT_PORT = '1883'
local MQTT_USER = 'mqtt'
local MQTT_PASSWORD = 'mqtt-secure'

local SPEAKERS_TOPIC = 'cmnd/tasmota_S26_2/POWER'

local cache = {}
local module = { cache = cache }

module.enableStudioAudio = function()
  log.d('enabling studio speakers')

  runScript('mosquitto_pub', {
    '-h',
    MQTT_HOST,
    '-p',
    MQTT_PORT,
    '-u',
    MQTT_USER,
    '-P',
    MQTT_PASSWORD,
    '-t',
    SPEAKERS_TOPIC,
    '-m',
    'ON',
  })
end

local applicationWatcher = function(appName, event)
  if event == hs.application.watcher.launched and appName == 'Music' and status.isStudioDisplayConnected then
    module.enableStudioAudio()
  end
end

module.start = function()
  cache.watcherApplication = hs.application.watcher.new(applicationWatcher)
  cache.watcherApplication:start()
end

module.stop = function()
  cache.watcherApplication:stop()
end

return module
