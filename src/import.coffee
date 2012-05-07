###
  import a Poemspace dm3 dump into dm4

  @todo transfer meta data like creator and timestamps
  time_created: '2012-02-06T19:58:05.880Z'
  time_modified: '2012-02-06T19:58:05.880Z'
  created_by: 'nicola'
###

async = require 'async'
dm4client = require 'dm4client'
fs = require 'fs'
_ = require 'underscore'
log = require 'winston'

# configure file log
log.add log.transports.File,
  filename: 'import.log'
  json: false

# connect dm4client
dm4 = dm4client.create()

# cache created topics by import data id
topicsById = {}

createTopic = (id, onSuccess, values) ->
  dm4.createTopic values, (topic) ->
    log.info "#{topic.type_uri}: #{topic.id} created"
    topicsById[id] = topic
    onSuccess()

createValueTopic = (uri, id, values, field, onSuccess) ->
  unless values[field]
    async.nextTick onSuccess
  else
    createTopic id, onSuccess,
      type_uri: uri
      value: values[field]

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

# read and parse dump
dump = fs.readFileSync process.argv[2] ? './data/poemspace-dump.json'
data = JSON.parse dump
log.info 'rows', data.total_rows

# initialize worker references
instanceCounter = {}
instances = []
instancesById = {}
relations = []

mapContactData = (composite, values) ->
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
  if values.Address
    composite['dm4.contacts.address_entry'] = [
      'dm4.contacts.address':
        'dm4.contacts.street': values.Address
    ]

# configure topic handle by type
typeMapping =

  'Account': (id, values, done) -> async.nextTick done

  'Bezirk': (id, values, done) ->
    createValueTopic 'dm4.poemspace.bezirk', id, values, 'Name', done

  'Einrichtungsart': (id, values, done) ->
    createValueTopic 'dm4.poemspace.art', id, values, 'Name', done

  'Email': (id, values, done) ->
    if not values.Subject and not values.Message
      log.warn "empty mail #{id}", values
      async.nextTick done
    else
      t =
        type_uri: 'dm4.poemspace.mail'
        composite:
          'dm4.poemspace.subject': values.Subject
      if values.From
        t.composite['dm4.poemspace.from'] = values.From
      if values.To
        t.composite['dm4.poemspace.to'] = values.To
      if values.Cc
        t.composite['dm4.poemspace.cc'] = values.Cc
      if values.Bcc
        t.composite['dm4.poemspace.bcc'] = values.Bcc
      if values.Message
        t.composite['dm4.poemspace.body'] = values.Message
      createTopic id, done, t

  'Institution': (id, values, done) ->
    unless values.Name
      log.error "institution without name #{id}", values
      async.nextTick done
    else
      t =
        type_uri: 'dm4.contacts.institution'
        composite:
          'dm4.contacts.institution_name': values.Name
      mapContactData t.composite, values
      createTopic id, done, t

  'Note': (id, values, done) ->
    if not values.Title and not values.Body
      log.warn "empty note #{id}", values
      async.nextTick done
    else
      t =
        type_uri: 'dm4.notes.note'
        composite:
          'dm4.notes.text': values.Body
          'dm4.notes.title': values.Title
      createTopic id, done, t

  'Kiez': (id, values, done) ->
    createValueTopic 'dm4.poemspace.kiez', id, values, 'Name', done

  'Kunstgattung': (id, values, done) ->
    createValueTopic 'dm4.poemspace.gattung', id, values, 'Name', done

  'Search Result': (id, values, done) -> async.nextTick done

  'Person': (id, values, done) ->
    unless values.Name
      log.error "person without name #{id}", values
      async.nextTick done
    else
      t =
        type_uri: 'dm4.contacts.person'
        composite:
          'dm4.contacts.person_name':
            'dm4.contacts.last_name': values.Name
      mapContactData t.composite, values
      createTopic id, done, t

  'Workspace': (id, values, done) ->
    unless values.Name
      log.error "workspace without name #{id}", values
      async.nextTick done
    else
      t =
        type_uri: 'dm4.poemspace.list'
        composite:
          'dm4.poemspace.listname': values.Name
      createTopic id, done, t

# create type name array and counter map
instanceTypes = (type for type of typeMapping)
instanceCounter[type] = 0 for type in instanceTypes

# create a flat object of field values
mapInstance = (values) ->
  instance = {}
  for field in values.fields
    if field.content
      instance[field.id] = field.content
  instance

# handle each data row of dump
for row in data.rows
#
  switch row.doc.type

    when 'Relation'
      type = row.doc.rel_type
      switch type
        when 'Relation'
          relations.push row.doc.rel_doc_ids
        when 'Auxiliary'
          # ignore search results
        else
          log.error "no mapping for relation type #{type} of doc #{row.id} found"

    when 'Topic'
      type = row.doc.topic_type
      if type in instanceTypes
        instanceCounter[type] += 1
        instances.push id: row.id, type: type, values: mapInstance row.doc
      else
        log.error "no mapping for topic type #{type} of doc #{row.id} found"

    else
      unless row.id is '_design/deepamehta3'
        log.error "no mapping for doc type #{row.doc.type} of doc #{row.id} found"


transferInstanceTopic = (instance, done) ->
  typeMapping[instance.type] instance.id, instance.values, done

transferRelation = (relation, done) ->
  r1 = topicsById[relation[0]]
  r2 = topicsById[relation[1]]
  if r1?.id and r2?.id
    createAssociation r1.id, r2.id, done
  else
    log.error 'unmapped association', relation
    async.nextTick done

async.forEachLimit instances, 10, transferInstanceTopic, (err) ->
# batch create topics
  if err
    log.error err
  else
    async.forEachLimit relations, 10, transferRelation, (err) ->
    # batch create relations
      if err
        log.error err
      log.info 'Relations:', relations.length
      log.info 'Instances:', instances.length
      for it in instanceTypes
        log.info it + ':', instanceCounter[it]
