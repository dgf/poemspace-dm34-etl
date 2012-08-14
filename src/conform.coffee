# III. conform mail recipients and sender

async = require 'async'

createIdsByNameHash = (instances) ->
  idsByName = {}
  for id, instance of instances
    idsByName[instance.Name] = id
  idsByName

module.exports = (log, stage, done) ->
  #
  recipients = []
  sender = []
  mails = stage.getInstances 'Email'
  persons = createIdsByNameHash stage.getInstances 'Person'
  institutions = createIdsByNameHash stage.getInstances 'Institution'

  findMailRelations = (id, mail, type, relations) ->
    if mail[type]
      for n in mail[type].split ','
        name = n.trim()
        if name
          rId = persons[name] ? institutions[name]
          unless rId
            log.info "ignore mail #{id} #{type} relation #{name}"
          else
            log.info "add mail #{id} #{type} relation #{name}"
            relations.push
              mail: id
              id: rId
              type: type

  for id, mail of mails
    findMailRelations id, mail, 'From', sender
    for type in ['To', 'Cc', 'Bcc']
      findMailRelations id, mail, type, recipients

  async.series [
    (callback) -> stage.saveInstances 'Recipient', recipients, callback
    (callback) -> stage.saveInstances 'Sender', sender, callback
  ], done
