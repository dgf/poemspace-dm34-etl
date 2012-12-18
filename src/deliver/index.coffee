# IV. deliver address parts and topics

async = require 'async'
dm4 = require('dm4client').create()

module.exports = (log, stage, done) ->

  # login and open default workspace
  dm4.login 'admin', '', (session) ->
    dm4.openSpace 'de.workspaces.deepamehta', (workspaceId) ->
      async.series
        parts: (callback) ->
          require('./parts') log, stage, dm4, callback
        topics: (callback) ->
          require('./topics') log, stage, dm4, callback
        , done
