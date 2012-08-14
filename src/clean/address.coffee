# split and map contact addresses

async = require 'async'
_ = require 'underscore'

mapCountry = (address, match) ->
  if match
    switch match
      when 'D'
        address.Country = 'Deutschland'
      else
        address.Country = match[1]

createAddress = ->
  Country: 'Deutschland'
  Street: ''
  Zipcode: ''
  City: ''
  Residual: ''

module.exports = (log, stage, done) ->

  # regex pattern callback map
  lineMapping =
    '^ *([^\\d]+)(\\d+[\\S-]?\\d*) *$': (line, match, address) ->
      # text and number: Soldinerstr 42 => street
      log.info 'Street', line
      address.Street = match[1].trim() + ' ' + match[2]

    '^ *([^\\d]+)(\\d+[\\S-]?\\d*),? +-?•? *(\\d+) +(\\S*) *(\\S?) *$': (line, match, address) ->
      # Kopfstraße 42 - 12053 Berlin D
      log.info 'Street Nr Zipcode City', line
      address.Street = match[1].trim() + ' ' + match[2].trim()
      address.Zipcode = match[3]
      address.City = match[4]
      mapCountry address, match[5]

    '^ *(\\d+),? +(\\S+) *(\\S?) *$': (line, match, address) ->
      # 13359 Berlin
      log.info 'Zipcode City', line
      address.Zipcode = match[1]
      address.City = match[2]
      mapCountry address, match[3]

    '^ *(\\S+) *- *(\\d+) +(\\S+)$': (line, match, address) ->
      # D - 10247 Berlin
      log.info 'Country - Zipcode City', line
      mapCountry address, match[1]
      address.Zipcode = match[2]
      address.City = match[3]

  # test each line mapping pattern and call the first match
  mapLine = (address, line) ->
    for pattern, mapping of lineMapping
      match = line.match pattern
      if match
        mapping line, match, address
        return
    # save unmapped data
    address['Residual'] += line + ' # '

  # split and map address lines
  mapAddress = (lines) ->
    slines = lines.split '\n'
    log.info 'map address', slines.join ','
    address = createAddress()
    for line in slines
      mapLine address, line
    address

  # split, map and cache each existing instance address
  addresses = {}
  cleanAndHashAddresses = (type) ->
    instances = stage.getInstances(type)
    for id, instance of instances
      address = instance.Address
      if address
        addresses[id] = _.extend mapAddress(address),
          type: type
          mail: instance.Email

  cleanAndHashAddresses 'Person'
  cleanAndHashAddresses 'Institution'
  done null, addresses
