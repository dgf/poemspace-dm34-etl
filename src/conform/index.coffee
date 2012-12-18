# III. conform mails and address parts

async = require 'async'

module.exports = (log, stage, done) ->

  async.series
    mails: (callback) ->
      require('./email') log, stage, callback
    addresses: (callback) ->
      require('./address') log, stage, callback
    , done
