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

  -t, --type         set the type name of CSV import
```

There is no special configuration, so please customize the Cakefile directly.
