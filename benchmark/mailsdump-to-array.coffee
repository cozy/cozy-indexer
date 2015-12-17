JSONStream = require 'JSONStream'
fs = require 'fs'
fs.createReadStream('mailsdump.json')
.pipe JSONStream.parse('rows.*.doc')
.pipe JSONStream.stringify('{"docs":[', ',', ']}')
.pipe fs.createWriteStream('mailsput.json')
