# V. import relations and enhance semantic topic associations

async = require 'async'
_ = require 'underscore'
dm4 = require('dm4client').create()

criteriaTypes = [
  'dm4.poemspace.bezirk'
  'dm4.poemspace.art'
  'dm4.poemspace.kiez'
  'dm4.poemspace.gattung'
]
module.exports = (log, stage, done) ->

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

  createWholePartAssociation = (type, whole, part, composite, onSuccess) ->
    a =
      type_uri: type
      composite: composite
      role_1:
        role_type_uri: 'dm4.core.whole'
        topic_id: whole
      role_2:
        role_type_uri: 'dm4.core.part'
        topic_id: part
    dm4.createAssociation a, (assoc) ->
      log.info "#{type} #{assoc.id}: #{assoc.role_1.topic_id} <-> #{assoc.role_2.topic_id}"
      onSuccess()

  # get ID of first email address or -1
  getFirstEmail = (topic) ->
    addresses = topic.composite['dm4.contacts.email_address']
    address = -1
    if addresses?.length > 0
      address = addresses[0].id
    else
      log.error 'mail reference without contact email address', topic
    address

  # create a mail recipient assocication
  createMailRecipient = (mail, related, type, onSuccess) ->
    composite =
      'dm4.mail.recipient.type': 'ref_id:' + type
      'dm4.contacts.email_address': [ 'ref_id:' + getFirstEmail topics[related] ]
    createWholePartAssociation 'dm4.mail.recipient',
      topics[mail].id, topics[related].id, composite, onSuccess

  # create a mail sender assocication
  createMailSender = (mail, related, onSuccess) ->
    composite =
      'dm4.contacts.email_address': 'ref_id:' + getFirstEmail topics[related]
    createWholePartAssociation 'dm4.mail.sender',
      topics[mail].id, topics[related].id, composite, onSuccess

  # aggregate a criterion
  createCriteriaAggregation = (topicId, criterionId, onSuccess) ->
    createWholePartAssociation 'dm4.core.aggregation', topicId, criterionId, {}, onSuccess

  # create a simple undirected association
  transferRelation = (relation, callback) ->
    r1 = topics[relation[0]]
    r2 = topics[relation[1]]
    if r1?.id and r2?.id
      if r1.type_uri in criteriaTypes
        createCriteriaAggregation r2.id, r1.id, callback
      else if r2.type_uri in criteriaTypes
        createCriteriaAggregation r1.id, r2.id, callback
      else
        createAssociation r1.id, r2.id, callback
    else
      log.error 'unmapped association', relation
      async.nextTick callback

  # create relations
  createRelations = (callback) ->
    async.forEachLimit stage.getRelations(), 1, transferRelation, callback

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
    async.forEachLimit recipients, 1, createRecipient, callback

  # create mail sender associations
  createSenders = (callback) ->
    sender = stage.getInstances 'Sender'
    createSender = (sender, callback) ->
      createMailSender(sender.mail, sender.id, callback)
    async.forEachLimit sender, 1, createSender, callback

  # login and open default workspace
  dm4.login 'admin', '', (session) ->
    dm4.openSpace 'de.workspaces.deepamehta', (workspaceId) ->
      getRecipientTypes (types) ->
        createRelations (err) ->
          if err then done err else createRecipients types, (err) ->
            if err then done err else createSenders done
