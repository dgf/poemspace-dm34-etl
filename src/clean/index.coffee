# II. clean
# clean and export addresses and person contacts

async = require 'async'
_ = require 'underscore'

module.exports = (log, stage, done) ->
  saveAndExport = (type, instances, callback, cols) ->
    stage.saveInstances type, instances, ->
      stage.saveCSV type, instances, cols, callback

  async.parallel
    addresses: (callback) ->
      require('./address') log, stage, callback
    names: (callback) ->
      require('./name') log, stage, callback
    , (err, results) ->
      done err if err?

      # persist addresses and contacts
      async.parallel [
        (callback) -> saveAndExport 'Address', results.addresses, callback,
          cols = ['type', 'Street', 'Zipcode', 'City', 'Country', 'Residual', 'mail']
        (callback) -> saveAndExport 'PersonName', results.names, callback,
          cols = ['Firstname', 'Lastname']
      ], done
