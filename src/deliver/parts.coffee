# deliver unique address parts

async = require 'async'
_ = require 'underscore'
{sanitize} = require '../etl.tools'

module.exports = (log, stage, dm4, done) ->

  createTopics = (type, uri, callback) ->
    instances = stage.getInstances type

    deliver = (instance, callback) ->
      dm4.createTopic { type_uri: uri, value: instance.value }, (topic) ->
        log.info "#{uri} #{topic.id} #{topic.value}"
        instances[topic.value].id = topic.id
        callback()

    arrayfie = () ->
      for value, instance of instances
        type: uri
        value: value

    async.forEachLimit arrayfie(), 1, deliver, ->
      stage.saveInstances type, instances, callback

  async.series [
    (callback) -> createTopics 'City', 'dm4.contacts.city', callback
    (callback) -> createTopics 'Country', 'dm4.contacts.country', callback
    (callback) -> createTopics 'Street', 'dm4.contacts.street', callback
    (callback) -> createTopics 'Zipcode', 'dm4.contacts.postal_code', callback
  ], done
