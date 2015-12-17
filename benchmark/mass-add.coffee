BATCH = 100
N = 10*BATCH
M = 1000000

heapdump = require 'heapdump'
async = require 'async'
indexer = require '../lib/index'
stream = require 'stream'
http = require 'http'

process.on 'uncaughtException', (err) ->
    console.log err.stack or err
    setTimeout (-> process.exit 1), 100

showRam = (tag) ->
    {rss, heapTotal, heapUsed} = process.memoryUsage()
    console.log tag, Math.round(rss/M), Math.round(heapTotal/M), Math.round(heapUsed/M)

definition =
    text:
        nGramLength: 1,
        stemming: true, weight: 1, fieldedSearch: false

    subject:
        nGramLength: {gte: 1, lte: 2},
        stemming: true, weight: 5, fieldedSearch: true

    date:
        filter: true, searchable: false

    accountID:
        filter: true, searchable: false

nextBatch = (callback) ->
    writable = new stream.Writable()
    writable.data = []
    writable._write = (chunk, enc, cb) ->
        @data.push chunk
        cb null

    http.get {hostname:'localhost', port:3006, path:'/', agent:false}, (res) ->
        res.pipe writable
        res.on 'end', ->
            # console.log "END", Buffer.concat(writable.data).toString('utf8').length
            # console.log "END", writable.data.length, Buffer.concat(writable.data).length
            # console.log "END", Buffer.concat(writable.data).length

            callback null, JSON.parse Buffer.concat(writable.data).toString('utf8')


indexer.cleanup (err) ->

    showRam "load    "
    heapdump.writeSnapshot('./result-load.heapsnapshot');
    finished = false
    i = 0

    http.get {hostname:'localhost', port:3006, path:'/reset', agent:false}, (res) ->
        res.on 'data', ->
        res.on 'end', ->

        async.whilst (-> not finished), (next) ->
            nextBatch (err, batch) ->
                if batch.length is 0
                    finished = true
                    return next null

                if i is 7
                    finished = true
                    batch = null
                    global.gc() for k in [0..10]
                    showRam "addbatch fin"
                    heapdump.writeSnapshot("./result-index-fin.heapsnapshot");
                    return next null

                # global.gc() for k in [0..10]
                showRam "addbatch #{i}"
                heapdump.writeSnapshot("./result-index-#{i}.heapsnapshot");
                i += 1

                indexer.addBatch batch, definition, (err) ->
                    setImmediate (-> next err)

        , (err) ->
            console.log "done, wait 30s", err
            setTimeout (-> console.log "done"), 30000

