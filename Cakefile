fs = require 'fs'
path = require 'path'
log = require 'winston'

Stage = require './src/StagingArea'
stage = new Stage()

green = '\x1b[0;32m'
reset = '\x1b[0m'
red = '\x1b[0;31m'

configureFileLog = (filename, append = false) ->
  unless append
    try
      fs.unlinkSync filename
    catch e
      throw e unless e.code is 'ENOENT'
  log.add log.transports.File,
    filename: filename
    json: false
  log.remove log.transports.Console

logMessage = (message, color = reset) ->
  console.log color + message + reset

logComplete = (err) ->
  uptime = Math.round(process.uptime() * 100) / 100
  if err?
    logMessage ":( #{uptime}s", red
  else
    logMessage ":) #{uptime}s", green

createDirectory = (path) ->
  try
    stat = fs.statSync(path)
    throw new Error 'init path ' + path unless stat.isDirectory()
  catch e
    if e.code is 'ENOENT' then fs.mkdirSync path else throw e

# pre check environment
createDirectory('log')
createDirectory('stage')

task 'extract', 'extract DM3 poem space dump data', ->
  configureFileLog path.join 'log', 'extract'
  require('./src/extract') log, stage, logComplete,
    path.join 'data', 'poemspace-dump-20121109.json'

task 'clean', 'clean extracted instances', ->
  configureFileLog path.join 'log', 'clean'
  require('./src/clean') log, stage, logComplete

option '-t', '--type [TYPE]', 'set the type name of CSV import'
task 'importCSV', 'import data from CSV file', (options) ->
  if options.type
    console.log options
    data = stage.getCSV options.type
    stage.saveInstances options.type, data, logComplete

task 'conform', 'conform topic instances and relations', ->
  configureFileLog path.join 'log', 'conform'
  require('./src/conform') log, stage, logComplete

task 'deliver', 'deliver instances as DM topics', ->
  configureFileLog path.join 'log', 'deliver'
  require('./src/deliver') log, stage, logComplete

task 'relate', 'deliver associations and relate mails', ->
  configureFileLog path.join 'log', 'relate'
  require('./src/relate') log, stage, logComplete
