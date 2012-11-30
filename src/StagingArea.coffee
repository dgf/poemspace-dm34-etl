# persistent staging area

fs = require 'fs'
path = require 'path'
util = require 'util'
async = require 'async'

# constants
directory = 'stage'
relationsFile = path.join directory, 'Relation.json'
COLSEP = '\t'

# file name path joining
getFilename = (type, suffix) -> path.join(directory, type) + suffix
getInstanceFilename = (type) -> getFilename type, '.json'
getCsvFilename = (type) -> getFilename type, '.csv'

loadCSV = (type) ->
  lines = fs.readFileSync(getCsvFilename(type), 'UTF-8').split '\n'
  fields = lines[0].split COLSEP
  data = {}
  for line in lines[1..]
    instance = {}
    for i, value of line.split COLSEP
      instance[fields[i]] = value
    if instance.id
      data[instance.id] = instance
    else
      util.error 'CSV entry without ID', instance
  data

loadInstances = (type) ->
  JSON.parse fs.readFileSync getInstanceFilename type

loadRelations = ->
  JSON.parse fs.readFileSync relationsFile

saveCSV = (type, data, cols, done) ->
  file = fs.createWriteStream getCsvFilename(type)
  file.on 'close', done
  file.write 'id\t' + cols.join(COLSEP) + '\n'
  for id, instance of data
    line = [id]
    for col in cols
      line.push instance[col] ? 'NULL'
    file.write line.join(COLSEP) + '\n'
  file.end()

saveJSON = (name, data, done) ->
  fs.writeFile name, JSON.stringify(data, null, 2), done

# export constructor
module.exports = ->

  # extract cache
  relations = []
  instancesByType = {}
  typeCountByName = {}

  getTypes = ->
    t for t, c of typeCountByName

  saveInstances = (type, done) ->
    saveJSON getInstanceFilename(type), instancesByType[type], done

  addInstance: (id, type, values) ->
    unless typeCountByName[type]
      typeCountByName[type] = 0
    typeCountByName[type] += 1
    unless instancesByType[type]
      instancesByType[type] = {}
    instancesByType[type][id] = values

  addRelation: (relation) ->
    relations.push relation

  getInstances: (type) ->
    unless instancesByType[type]
      instancesByType[type] = loadInstances type
    instancesByType[type]

  getRelations: ->
    unless relations.length > 0
      relations = loadRelations()
    console.log "return #{relations.length} relations"
    relations

  getCSV: (type) ->
    unless instancesByType[type]
      instancesByType[type] = loadCSV type
    instancesByType[type]

  # save extracted data
  saveExtract: (done) ->
    console.log 'save data of staging area'
    async.parallel [
      (callback) -> saveJSON relationsFile, relations, callback
      (callback) -> async.forEachLimit getTypes(), 7, saveInstances, callback
    ], (err, results) ->
      if err
        done err
      else
        console.log 'Relations:', relations.length
        console.log type + ':', count for type, count of typeCountByName
        done()

  saveInstances: (type, data, done) ->
    console.log "save #{type} instances"
    saveJSON getInstanceFilename(type), data, done

  saveCSV: (type, data, cols, done) ->
    console.log "save #{type} CSV"
    saveCSV type, data, cols, done
