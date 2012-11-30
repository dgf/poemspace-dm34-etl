# IV. deliver topics and associations 

async = require 'async'
_ = require 'underscore'
dm4 = require('dm4client').create()

trimChars = (string, chars) ->
  s = string
  remove = (pattern) -> s = s.replace pattern, ''
  for char in chars
    remove new RegExp '^' + char
    remove new RegExp char + '$'
  s

sanitize = (string) ->
  if string?
    trimChars string.trim(), [',', ';']
  else
    'n/a'

mapContact = (composite, values) ->
  composite['dm4.contacts.notes'] = sanitize values.Notes if values.Notes
  if values.Phone
    composite['dm4.contacts.phone_entry'] = []
    for phone in values.Phone.split '\n'
      composite['dm4.contacts.phone_entry'].push
        'dm4.contacts.phone_number': sanitize phone
  if values.Email
    composite['dm4.contacts.email_address'] = []
    for mail in values.Email.split '\n'
      composite['dm4.contacts.email_address'].push sanitize mail
  if values.Website
    composite['dm4.webbrowser.url'] = []
    for site in values.Website.split '\n'
      composite['dm4.webbrowser.url'].push sanitize site

mapPersonName = (composite, values = {}) ->
  name = {}
  name['dm4.contacts.first_name'] = sanitize values.Firstname if values.Firstname
  name['dm4.contacts.last_name'] = sanitize values.Lastname if values.Lastname
  composite['dm4.contacts.person_name'] = name

mapAddress = (composite, values = {}) ->
  address = {}
  address['dm4.contacts.street'] = sanitize values.Street if values.Street
  address['dm4.contacts.postal_code'] = sanitize values.Zipcode if values.Zipcode
  address['dm4.contacts.city'] = sanitize values.City if values.City
  address['dm4.contacts.country'] = sanitize values.Country if values.Country
  composite['dm4.contacts.address_entry'] = [
    'dm4.contacts.address': address
  ]
  if values.Residual
    notes = composite['dm4.contacts.notes'] ? ''
    composite['dm4.contacts.notes'] = values.Residual.replace('#', '<br/>\n') + '<br/>\n' + notes

module.exports = (log, stage, done) ->

  # cache created topics by import data id
  topicsById = {}

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
      createTopic id, { type_uri: uri, value: sanitize values[field] }, onSuccess

  # preload addresses and person names
  addressesByInstanceId = stage.getInstances 'Address'
  namesByInstanceId = stage.getInstances 'PersonName'

  # configure topic handle by type
  typeMapping =

    'Account': (id, values, callback) ->
      a =
        type_uri: 'dm4.accesscontrol.user_account'
        composite:
          'dm4.accesscontrol.username': values.Username
          'dm4.accesscontrol.password': values.Password
      createTopic id, a, callback

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
            'dm4.mail.subject': sanitize values.Subject
        if values.Message
          t.composite['dm4.mail.body'] = sanitize values.Message
        createTopic id, t, callback

    'Institution': (id, values, callback) ->
      unless values.Name
        log.error "institution without name #{id}", values
        async.nextTick callback
      else
        t =
          type_uri: 'dm4.contacts.institution'
          composite:
            'dm4.contacts.institution_name': sanitize values.Name
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
            'dm4.notes.text': sanitize values.Body
            'dm4.notes.title': sanitize values.Title
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
            'dm4.poemspace.listname': sanitize values.Name
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
    async.forEachLimit instances, 1, transferInstanceTopic, callback

  # login and open default workspace
  dm4.login 'admin', 'password', (session) ->
    dm4.openSpace 'de.workspaces.deepamehta', (workspaceId) ->
      async.forEachSeries [
        'Account'
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
