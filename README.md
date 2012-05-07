# Poemspace - DeepaMehta 3 to 4 data transfer

Imports [Poemspace](http://www.poem-space.com) data dump of the
[dm3-poemspace-app](https://github.com/jri/dm3-poemspace-app.git) to the
[DeepaMehta 4](http://github.com/jri/deepamehta) based
[Poemspace plugin](https://github.com/dgf/poemspace)

## Requirements

  * [DeepaMehta 4](http://github.com/jri/deepamehta)
  * [Poemspace plugin](http://github.com/dgf/poemspace)

## Usage

  1. start DeepaMehta 4 and install the Poemspace plugin
  2. save the DeepaMehta 3 dump in the data directory
  3. install dependencies and run the importer
```shell
npm install
```
    import data data/poemspace-dump.json
```shell
npm start
```
    or an other file
```shell
coffee src/import.coffee data/poemspace-dump-20120421.json
```
