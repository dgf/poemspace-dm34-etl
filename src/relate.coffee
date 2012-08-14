# V. import relations and enhance semantic topic associations

async = require 'async'
_ = require 'underscore'
dm4client = require 'dm4client'

module.exports = (log, stage, done) ->

  # connect dm4client
  dm4 = dm4client.create()

  # get delivered topics
  topics = stage.getInstances 'Topic'

  # create an assocication
  createAssociation = (r1, r2, onSuccess) ->
    a =
      type_uri: 'dm4.core.association'
      role_1:
        role_type_uri: 'dm4.core.default'
        topic_id: r1
      role_2:
        role_type_uri: 'dm4.core.default'
        topic_id: r2
    dm4.createAssociation a, (assoc) ->
      log.info "#{assoc.id}: #{assoc.role_1.topic_id} <-> #{assoc.role_2.topic_id}"
      onSuccess()

  # create a mail recipient assocication
  createMailRecipient = (mail, related, type, onSuccess) ->
    a =
      type_uri: 'dm4.mail.recipient'
      role_1:
        role_type_uri: 'dm4.core.whole'
        topic_id: topics[mail].id
      role_2:
        role_type_uri: 'dm4.core.part'
        topic_id: topics[related].id
      composite:
        'dm4.mail.recipient.type': 'ref_id:' + type
    dm4.createAssociation a, (assoc) ->
      log.info "#{assoc.id}: #{assoc.role_1.topic_id} <-> #{assoc.role_2.topic_id}"
      onSuccess()

  # create a mail sender assocication
  createMailSender = (mail, related, onSuccess) ->
    a =
      type_uri: 'dm4.mail.from'
      role_1:
        role_type_uri: 'dm4.core.whole'
        topic_id: topics[mail].id
      role_2:
        role_type_uri: 'dm4.core.part'
        topic_id: topics[related].id
    dm4.createAssociation a, (assoc) ->
      log.info "#{assoc.id}: #{assoc.role_1.topic_id} <-> #{assoc.role_2.topic_id}"
      onSuccess()

  # create a simple undirected association
  transferRelation = (relation, callback) ->
    r1 = topics[relation[0]]
    r2 = topics[relation[1]]
    if r1?.id and r2?.id
      createAssociation r1.id, r2.id, callback
    else
      log.error 'unmapped association', relation
      async.nextTick callback

  # create relations
  createRelations = (callback) ->
    async.forEachLimit stage.getRelations(), 10, transferRelation, callback

  # get types
  getRecipientTypes = (callback) ->
    dm4.getTopics 'dm4.mail.recipient.type', (types) ->
      typesByName = {}
      for type in types
        typesByName[type.value] = type.id
      callback typesByName

  # create recipient assocications
  createRecipients = (types, callback) ->
    recipients = stage.getInstances 'Recipient'
    createRecipient = (recipient, callback) ->
      type = types[recipient.type]
      createMailRecipient(recipient.mail, recipient.id, type, callback)
    async.forEachLimit recipients, 10, createRecipient, callback

  # create mail sender associations
  createSenders = (callback) ->
    sender = stage.getInstances 'Sender'
    createSender = (sender, callback) ->
      createMailSender(sender.mail, sender.id, callback)
    async.forEachLimit sender, 10, createSender, callback

  # go
  getRecipientTypes (types) ->
    createRelations (err) ->
      if err then done err else createRecipients types, (err) ->
        if err then done err else createSenders done
