# I. extract instances and relations from a DM3 poemspace dump file

fs = require 'fs'

# create a flat hash of exist field values
mapInstance = (values) ->
  instance = {}
  for field in values.fields
    if field.content
      instance[field.id] = field.content
  instance

module.exports = (log, stage, done, dumpFile = './data/poemspace-dump.json') ->

  # report error on console too
  logError = (m) ->
    console.error m
    log.error m

  # read and parse dump
  data = JSON.parse fs.readFileSync dumpFile
  log.info 'rows', data.total_rows

  # handle each data row of dump
  for row in data.rows
    switch row.doc.type

      when 'Relation'
        switch row.doc.rel_type

          when 'Relation'
            log.info 'extract relation', row.id
            stage.addRelation row.doc.rel_doc_ids
          when 'Auxiliary'
            log.debug 'ignore auxiliary', row.id
          else
            logError "no mapping for relation type #{row.doc.rel_type} of doc #{row.id} found"

      when 'Topic'
        switch row.doc.topic_type

          when 'Search Result'
            log.debug 'ignore search result', row.id
            stage.addInstance row.id, 'Ignored', type: 'Search Result'
          else
            log.info 'extract instance', row.id
            stage.addInstance row.id, row.doc.topic_type, mapInstance row.doc

      else
        unless row.id is '_design/deepamehta3'
          logError "no mapping for doc type #{row.doc.type} of doc #{row.id} found"

  # save stage data and report success
  stage.saveExtract done
