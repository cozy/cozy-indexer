indexer = require '../src/index'
should = require 'should'
async = require 'async'


DOCS = require './fixtures.json'

noteIndexDefinition =
    docType:
        filter: true, searchable: false
    tags:
        filter: true
    title:
        nGramLength: {gte: 1, lte: 2},
        stemming: true, weight: 5, fieldedSearch: false
    content:
        nGramLength: {gte: 1, lte: 2},
        stemming: true, weight: 1, fieldedSearch: false

fileIndexDefinition =
    docType:
        filter: true, searchable: false
    tags:
        filter: true
    name:
        nGramLength: {gte: 1, lte: 2},
        stemming: true, weight: 1, fieldedSearch: false


describe "Indexing API", ->

    before (done) ->
        indexer.init (err) ->
            console.log err if err
            indexer.cleanup done

    it "When I add 3 note in english", (done) ->
        indexer.addBatch DOCS[0..2], noteIndexDefinition, done

    it "When I add 1 file in english", (done) ->
        indexer.addBatch DOCS[3..], fileIndexDefinition, done


describe "Searching", ->

    it "Search for a note about accents", (done) ->
        params =
            search: '*': ['accents']
            facets: docType: {}
            filter: docType: [['note', 'note']]

        indexer.search params, (err, results) ->
            "fake_id_note_fra".should.equal results.hits[0]?.id
            done null


    it "Search for a note about étranges accents", (done) ->
        params =
            search: '*': ['étrange accent']
            facets: docType: ['note']

        indexer.search params, (err, results) ->
            "fake_id_note_fra".should.equal results.hits[0]?.id
            done null

    it "Search for everything about journée", (done) ->
        params =
            search: '*': ['journée']
            facets:
                docType: {}
                tags: {}

        indexer.search params, (err, results) ->
            results.hits.length.should.equal 2
            done null

describe "Store API", ->

    it "Allow to store data along the index", (done) ->
        indexer.store.set "test", 'value', done

    it "Allow to retrieve the data", (done) ->
        indexer.store.get "test", (err, value) ->
            return done err if err
            value.should.equal 'value'
            done null


describe "Merge indexDefinitions", ->
