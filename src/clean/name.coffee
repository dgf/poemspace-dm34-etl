# split and map person names

module.exports = (log, stage, done) ->

  mapping =
    '^ *(\\S+) +(\\S+) *$': (line, match, name) ->
      log.info 'Name', line
      name.Firstname = match[2]
      name.Lastname = match[1]

  # test each line mapping pattern and call the first match
  mapName = (name, line) ->
    for pattern, map of mapping
      match = line.match pattern
      if match
        map line, match, name
        return
    # save unmapped name as lastname
    name.Lastname = line

  # get persons and process the name of each
  names = {}
  for id, instance of stage.getInstances('Person')
    name = instance.Name
    if name
      personName =
        Firstname: ''
        Lastname: ''
      mapName personName, name
      names[id] = personName

  done null, names
