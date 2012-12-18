# Poemspace - DeepaMehta 3 to 4 data transfer

Imports [Poemspace](http://www.poem-space.com) data dump of the
[dm3-poemspace-app](https://github.com/jri/dm3-poemspace-app.git) to the
[DeepaMehta 4](http://github.com/jri/deepamehta) based
[Poemspace plugin](https://github.com/dgf/poemspace)

## Requirements

  * [DeepaMehta 4](http://github.com/jri/deepamehta) > 4.0.12
  * [Poemspace plugin](http://github.com/dgf/poemspace)

## Usage

  1. start DeepaMehta 4 and install the Poemspace plugin
  2. save the DeepaMehta 3 dump (CouchDB export)
  3. install dependencies and run the importer

```sh
$ npm install
```

call a ETL task
```sh
$ cake
Cakefile defines the following tasks:

cake extract              # extract DM3 poem space dump data
cake clean                # clean extracted instances
cake importCSV            # import data from CSV file
cake conform              # conform topic instances and relations
cake deliver              # deliver instances as DM topics
cake relate               # deliver associations and relate mails

  -d, --dump         file name of DM3 export
  -t, --type         type name of CSV import
```

There is no special configuration, so please customize the Cakefile directly.

## import process

### extract

configure dump filename or use the default path './data/poemspace-dump.json'

```shell
$ cake -d ./data/poemspace-dump-20121216.json extract
```

### clean

split address lines and separate person names

```shell
$ cake clean
```

and now use the chance to edit the addresses and names in a spreadsheet
open 'stage/Address.csv' as tab separated CSV and import it back with
$ cake -t (Address|PersonName) importCSV # optional


### deliver

start a fresh DM 4 instance with the Poem Space plugin (migrationNr=12)

import all topics and address parts to DM 4 at localhost with

```shell
$ cake deliver
```

### relate

import all relations and create recipent/sender associations

```shell
$ cake relate
```

### customer specific content migrations

change the migrationNr to 14 and reload the plugin

