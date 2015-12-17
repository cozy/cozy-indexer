http = require 'http'

mails = require './mails'
i = 0
BATCH = 100
N = 10*BATCH

console.log "READY"

http.request  createServer (req, res) ->
  res.writeHead 200, {'Content-Type': 'application/json'}
  out = JSON.stringify mails[i..i+BATCH]
  console.log "ping", i
  res.write out
  i += BATCH
  res.end()

.listen 3006