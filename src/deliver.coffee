# IV. deliver topics and associations 

async = require 'async'
_ = require 'underscore'
dm4client = require 'dm4client'

mapContact = (composite, values) ->
  if values.Notes
    composite['dm4.contacts.notes'] = values.Notes
  if values.Phone
    composite['dm4.contacts.phone_entry'] = []
    for phone in values.Phone.split '\n'
      composite['dm4.contacts.phone_entry'].push
        'dm4.contacts.phone_number': phone
  if values.Email
    composite['dm4.contacts.email_address'] = []
    for mail in values.Email.split '\n'
      composite['dm4.contacts.email_address'].push mail
  if values.Website
    composite['dm4.webbrowser.url'] = []
    for site in values.Website.split '\n'
      composite['dm4.webbrowser.url'].push site

mapPersonName = (composite, values = {}) ->
  name = {}
  if values.Firstname
    name['dm4.contacts.first_name'] = values.Firstname
  if values.Lastname
    name['dm4.contacts.last_name'] = values.Lastname
  composite['dm4.contacts.person_name'] = name

mapAddress = (composite, values = {}) ->
  address = {}
  if values.Street
    address['dm4.contacts.street'] = values.Street
  if values.Zipcode
    address['dm4.contacts.postal_code'] = values.Zipcode
  if values.City
    address['dm4.contacts.city'] = values.City
  if values.Country
    address['dm4.contacts.country'] = values.Country
  composite['dm4.contacts.address_entry'] = [
    'dm4.contacts.address': address
  ]

module.exports = (log, stage, done) ->

  # cache created topics by import data id
  topicsById = {}

  # connect dm4client
  dm4 = dm4client.create()

  # create and cache a topic
  createTopic = (id, values, onSuccess) ->
    dm4.createTopic values, (topic) ->
      log.info "#{topic.type_uri}: #{topic.id} created"
      topicsById[id] = topic
      onSuccess()

  # call helper to create and cache a topic
  createValueTopic = (uri, id, values, field, onSuccess) ->
    unless values[field]
      async.nextTick onSuccess
    else
      createTopic id, { type_uri: uri, value: values[field] }, onSuccess

  # preload addresses and person names
  addressesByInstanceId = stage.getInstances 'Address'
  namesByInstanceId = stage.getInstances 'PersonName'

  # configure topic handle by type
  typeMapping =

    'Bezirk': (id, values, callback) ->
      createValueTopic 'dm4.poemspace.bezirk', id, values, 'Name', callback

    'Einrichtungsart': (id, values, callback) ->
      createValueTopic 'dm4.poemspace.art', id, values, 'Name', callback

    'Email': (id, values, callback) ->
      if not values.Subject and not values.Message
        log.warn "empty mail #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.mail'
          composite:
            'dm4.mail.subject': values.Subject
        if values.Message
          t.composite['dm4.mail.body'] = values.Message
        createTopic id, t, callback

    'Institution': (id, values, callback) ->
      unless values.Name
        log.error "institution without name #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.contacts.institution'
          composite:
            'dm4.contacts.institution_name': values.Name
        mapContact t.composite, values
        mapAddress t.composite, addressesByInstanceId[id]
        createTopic id, t, callback

    'Note': (id, values, callback) ->
      if not values.Title and not values.Body
        log.warn "empty note #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.notes.note'
          composite:
            'dm4.notes.text': values.Body
            'dm4.notes.title': values.Title
        createTopic id, t, callback

    'Kiez': (id, values, callback) ->
      createValueTopic 'dm4.poemspace.kiez', id, values, 'Name', callback

    'Kunstgattung': (id, values, callback) ->
      createValueTopic 'dm4.poemspace.gattung', id, values, 'Name', callback

    'Person': (id, values, callback) ->
      unless values.Name
        log.error "person without name #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.contacts.person'
          composite: {}
        mapContact t.composite, values
        mapPersonName t.composite, namesByInstanceId[id]
        mapAddress t.composite, addressesByInstanceId[id]
        createTopic id, t, callback

    'Workspace': (id, values, callback) ->
      unless values.Name
        log.error "workspace without name #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.poemspace.list'
          composite:
            'dm4.poemspace.listname': values.Name
        createTopic id, t, callback

  # call corresponding type mapping
  transferInstanceTopic = (instance, callback) ->
    typeMapping[instance.type] instance.id, instance.values, callback

  # create array from object, save key as id value
  arrayfie = (type, object) ->
    for id, values of object
      result =
        id: id
        type: type
        values: values

  # create mapped topic instances
  createTopics = (type, callback) ->
    instances = arrayfie type, stage.getInstances type
    async.forEachLimit instances, 10, transferInstanceTopic, callback

  async.forEachSeries [
    'Bezirk'
    'Einrichtungsart'
    'Email'
    'Institution'
    'Kiez'
    'Kunstgattung'
    'Note'
    'Person'
    'Workspace'
  ], createTopics, (err) ->
    if err
      done err
    else
      stage.saveInstances 'Topic', topicsById, done
