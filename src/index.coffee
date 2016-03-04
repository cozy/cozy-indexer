Math.log10 ?= (val) -> return Math.log(val) / Math.LN10

searchIndex = require 'search-index'
franc = require 'franc'
async = require 'async'
path = require 'path'
{exec} = require 'child_process'
natural = require 'natural'


SEPARATOR = ' '

indexPath = process.env.INDEXES_PATH or '../search-indexes'

stemmers =
    en: require('natural/lib/natural/stemmers/porter_stemmer')
    fr: require('natural/lib/natural/stemmers/porter_stemmer_fr')

defaultTokenizer = new natural.WordTokenizer()

francOptions =
    minLength: 3
    whitelist: ['eng', 'fra']

siOptions =
    indexPath: path.resolve __dirname, indexPath
    fieldsToStore: []
    stopwords: []
    separator: SEPARATOR
    # log: require('bunyan').createLogger({name: 'searchindex'})


helpers =
    ###*
    # Stem the given text by guessing its lang using `franc`
    #
    # @param {string} text value to stem
    # @param {boolean} includeOriginal include the original text in output,
    #                  allow to get matches even if content stemming was not done
    #                  in the same language than query.
    #
    # @return {string} the stemmed text
    ###
    stem: (text, includeOriginal = true) ->
        lang = franc(text, francOptions).substring 0, 2
        if lang of stemmers
            out = stemmers[lang].tokenizeAndStem(text)
        else
            out = defaultTokenizer.tokenize(text)

        out.push text if includeOriginal
        return out.join(SEPARATOR)

    ###*
    # Prepare a value for indexing
    # support all type of value (scalar, array, object, undefined)
    # the final value should be a string for non-faceted fields and
    # an array for faceted fields.
    #
    # | value            |  normal      |  stemmed      |   faceted  |
    # | ---------------- | ------------ | ------------- | ---------- |
    # | {a: "test"}      | "a test"     | stem "a test" | NA         |
    # | ['a', 'b']       | "a b"        | stem "a b"    | ['a', 'b'] |
    # | 'Hello'          | "Hello"      | stem "Hello"  | ['hello']  |
    # | null / undefined | undefined    | undefined     | undefined  |
    #
    # @param {mixed} value value to transform
    # @param {boolean} stemmed should we stem the value
    # @param {boolean} facet is this fact
    #
    # @return {string|array} the value prepared. Will be an array if
    #         the field is to be facet, string otherwise
    ###
    prepareField: (value, stemmed, facet, includeObjectKeys) ->

        unless value
            value = undefined

        else if typeof value is 'string'
            value = helpers.stem value if stemmed
            value = [value.toLowerCase()] if facet

        else if Array.isArray(value)
            value = value.map (part) -> helpers.prepareField part, stemmed
            value = value.join SEPARATOR unless facet

        else if typeof value is 'object'
            joined = []
            for k, v of value
                joined.push k if includeObjectKeys
                joined.push helpers.prepareField v, stemmed
            value = joined.join SEPARATOR

        return value

    ###*
    # Prepare a document for indexing
    # Copy properties from one to a new object, as Cradle response are not
    # simple javascript object and this breaks search-index
    # Pass each field into prepareField
    #
    # @param {object} the document to transform
    # @param {options} the makeBatchOptions return value
    #
    # @return {object} the document prepared.
    ###
    makeIndexableDoc: (doc, options) ->
        indexable = {id: doc._id}
        for own field, value of doc
            isStem = field in options.stemmedFields
            isFacet = field in options.facetFields
            indexable[field] = helpers.prepareField value, isStem, isFacet

        for field in options.facetFields when not indexable[field]
            indexable[field] = undefined

        return indexable


    ###*
    # Transform the configuration passed to addBatch into search-index format
    # @TODO memoize this
    #
    # @param {object} fieldOptions the options to transform
    #
    # @return {object} options prepared.
    ###
    makeBatchOptions: (fieldOptions) ->

        batchOptions =
            fieldsToStore: [] # none
            fieldOptions: []
            stemmedFields: []
            includeObjectKeys: []
            facetFields: []
            defaultFieldOptions:
                searchable: false
                fieldedSearch: false

        for field, fieldOption of fieldOptions
            fieldOption.fieldName = field
            fieldOption.searchable ?= true
            batchOptions.fieldOptions.push fieldOption
            if fieldOption.stemming
                batchOptions.stemmedFields.push field
            if fieldOption.filter
                batchOptions.facetFields.push field
            if fieldOption.includeObjectKeys
                batchOptions.includeObjectKeys.push field

        batchOptions.fieldOptions.push
            fieldName: '*', searchable: true, fieldedSearch: true,

        return batchOptions


    mergeNGramsLengths: (oldvalue, newvalue) ->

        unless newvalue
            return oldvalue

        unless oldvalue
            return newvalue

        ogte = oldvalue.gte or oldvalue
        olte = oldvalue.lte or oldvalue
        ngte = newvalue.gte or newvalue
        nlte = newvalue.lte or newvalue

        gte = Math.min(ogte, ngte)
        lte = Math.max(olte, nlte)

        if gte is ogte and lte is olte
            return oldvalue
        else
            return {gte, lte}


module.exports = indexer =
    si: null


    init: (callback) ->
        searchIndex siOptions, (err, si) ->
            indexer.si = si
            callback err, si

    ###*
    # Prepare a document for indexing
    # Copy properties from one to a new object, as Cradle response are not
    # simple javascript object and this breaks search-index
    # Pass each field into prepareField
    #
    # @param {object} the document to transform
    # @param {options} a map of fieldName to the options for indexing
    #
    # @return {object} the document prepared.
    ###
    addBatch: (docs, fieldOptions, callback) ->

        return callback null if docs.length is 0

        options = helpers.makeBatchOptions fieldOptions
        batch = []
        for doc in docs
            indexable = helpers.makeIndexableDoc doc, options
            if indexable then batch.push indexable
            else console.log """
                ignoring doc without indexable field #{doc._id}
            """

        if batch.length then indexer.si.add batch, options, callback
        else setImmediate callback


    ###*
    # Simple store api to put data in the index, used by the DS to ensure
    # sync is correct.
    ###
    store:
        open: (callback) ->
            checkIfOpen = ->
                return callback null if indexer.si.indexes.isOpen()
                setTimeout checkIfOpen, 100
            checkIfOpen()
        set: (key, value, callback) ->
            indexer.si.options.indexes.put 'KV￮' + key + '￮', value, callback
        get: (key, callback) ->
            indexer.si.options.indexes.get 'KV￮' + key + '￮', callback


    ###*
    # Remove a document from the index
    #
    # @params {string} docID
    #
    # @return (callback) when the operation is complete
    ###
    forget: (docID, callback) ->
        indexer.si.del docID, callback


    ###*
    # Perform a search
    #
    # @params {object} (options) search parameters
    # @params {object} options.search a Map(fieldname -> [search terms])
    # @params {object} options.pageSize
    # @params {object} options.facets a Map(fieldname -> facets options)
    # @params {object} options.filter a Map(fieldname -> facets values)
    # @params {string} lang 2 letter code for the lang this query is in
    #
    # @return (callback) the result of the search
    ###
    search: (options, callback) ->

        query = {}
        stemTerm = (term) -> helpers.stem term, false
        for field, search of options.search
            query[field] = search.map stemTerm

        params =
            query: query
            offset: options.offset
            pageSize: options.pageSize
            facets: options.facets
            filter: options.filter

        try indexer.si.search params, callback
        catch err then callback err


    ###*
    # The normal cleanup method of search-index is too slow
    # instead we just rm -rf the whole index folder
    #
    # @returns (callback) when the db is open again
    ###
    cleanup: (callback) ->
        indexer.si.options.indexes.close (err) ->
            return callback err if err
            exec "rm -rf #{indexPath}", (err) ->
                return callback err if err

                opts =
                    indexPath: indexPath
                    fieldsToStore: []
                    stopwords: []
                searchIndex opts, (err, si) ->
                    indexer.si = si
                    indexer.si.options.indexes.open callback


    ###*
    # If two applications wants to index a same field using different parameters
    # this function will try to find the best common ground.
    # If there is no change to be made to olddef, we return the actual oldef
    # object, so it is easy to check
    #        mixed = mergeFieldDef oldef, newdef
    #        if mixed === olddef # nothing has changed
    #
    # This function should be convergent
    #        merge(A, B) -> C
    #        merge(C, A) -> C
    #        merge(C, B) -> C
    #
    # @params {object} olddef the current definition for the field
    # @params {object} newdef the new definition for the field
    # @returns {object} olddef if there is no need to change it, a mix of both
                        otherwise
    ###
    mergeFieldDef: (olddef, newdef) ->
        return newdef unless olddef

        changed = false
        merged = {}
        merged[k] = v for k, v of olddef

        trueWins = (name) ->
            if olddef[name] is false and newdef[name]
                changed = true
                merged[name] = true

        trueWins 'searchable'
        trueWins 'fieldedSearch'
        trueWins 'stemming'

        if olddef.weight < newdef.weight
            changed = true
            merged.weight = Math.max(olddef.weight, newdef.weight)

        nGramLength = mergeNGramsLengths olddef.nGramLength, newdef.nGramLength
        if nGramLength isnt olddef.nGramLength
            changed = true
            merged.nGramLength = nGramLength

        if changed
            return merged
        else
            return olddef

