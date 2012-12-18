# conform address parts

async = require 'async'
{sanitize} = require '../etl.tools'

addSanitize = (map, value) ->
  v = sanitize value
  if v?
    if map[v]?
      map[v].count++
    else
      map[v] =
        count: 1
        value: v

module.exports = (log, stage, done) ->
  addresses = stage.getInstances 'Address'

  cities = {}
  codes = {}
  countries = {}
  streets = {}

  for id, address of addresses
    addSanitize cities, address.City
    addSanitize codes, address.Zipcode
    addSanitize countries, address.Country
    addSanitize streets, address.Street

  async.series [
    (callback) -> stage.saveInstances 'City', cities, callback
    (callback) -> stage.saveInstances 'Country', countries, callback
    (callback) -> stage.saveInstances 'Street', streets, callback
    (callback) -> stage.saveInstances 'Zipcode', codes, callback
  ], done
