## [Cozy](http://cozy.io) Node Indexer

Overlay to [search-index](http://npmjs.com/package/search-index) with support
for stemming and internationalization using [natural](http://npmjs.com/package/natural) and [franc](http://npmjs.com/package/franc).

## API

```coffee
    OPTIONS =
        docType:
            filter: true
        tags:
            filter: true
        title:
            nGramLength: 1,
            stemming: true, weight: 5, fieldedSearch: true
        content:
            nGramLength: {gte: 1, lte: 2},
            stemming: true, weight: 1, fieldedSearch: false

    DOC = {
        "_id":"fake_id_note_eng",
        "docType": "Note",
        "title": "Hello world",
        "content": "This is an english note with some information.",
        "tags": ["tagA", "tagged"]
    }

    indexer.addBatch [DOC], OPTIONS, callback

    QUERY_OPTIONS = {
        query:
            "*": "cozy" # search cozy in all fields
            "title":"indexing" # AND indexing in title
        pageSize: 5 # 5 docs per page
        offset: 2 # 2nd page
        facets:
            docType: {}
        filter:
            date: [ # search something at the end of this or last month
                ['2015-10-25', '2015-10-30'],
                ['2015-11-25', '2015-11-30'],
            ]
    }

    indexer.search QUERY_OPTIONS, (err, results) ->
        results.totalHits === 16 # total number of matching docs
        results.hits === [{
            {id: "docid"}
            {id: "docid2"}
            ...
        }] # ids of the 5 docs in 2nd page
        results.facets[0] === { key: 'docType', value: [
            { key: 'note', value: 3 },
            { key: 'file', value: 13 }
        ] } # there is 13 file and 3 note matching our query
```

## Used libraries limitations and effects

The following problems have been encoutered with search-index

- No hook for tokenization : force us to .split(natural).join(separator)
  so that search-index can .split(separator)
- No OR request : would allow to just stem text and perform a double query
  if we cant guess the language of the query
- Fail when docs are not pure javascript object : incompatible with
  flatiron/cradle in the ds, investigate using the `raw` options of cradle

The following problems have been encoutered with natural

- no german stemmer


## What about the [former indexer](https://github.com/cozy/cozy-indexer)

This library is a replacement for it, the former indexer is not used anymore
by the Data System and can be safely uninstalled.

## Hack

    git clone https://github.com/cozy/cozy-indexer.git
    cd cozy-indexer
    npm install

    # make changes in ./src

    npm run build


## Tests

    npm run test

[![Build
Status](https://travis-ci.org/cozy/cozy-indexer.png?branch=master)](https://travis-ci.org/cozy/cozy-indexer)

## License

Cozy Data System is developed by Cozy Cloud and distributed under the AGPL v3 license.

## What is Cozy?

![Cozy Logo](https://raw.github.com/cozy/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you.

## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://forum.cozy.io/)
* Posting issues on the [Github repos](https://github.com/cozy/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
