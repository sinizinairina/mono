sync = require 'synchronize'
_    = require 'underscore'
{MongoClient, Db, Collection, Cursor} = module.exports = require 'mongodb'

# Clear database.
Db::clear = (callback) ->
  throw new Error "callback required!" unless callback

  @collectionNames (err, names) =>
    return callback err if err
    names = _(names).collect (obj) -> obj.name.replace(/^[^\.]+\./, '')
    names = _(names).select((name) -> !/^system\./.test(name))

    counter = 0
    dropNext = =>
      if counter == names.length then callback()
      else
        name = names[counter]
        counter += 1
        @collection name, (err, collection) ->
          return callback err if err
          collection.drop (err) ->
            return callback err if err
            dropNext()
    dropNext()

# Synchronising.
sync MongoClient, 'connect'
sync Db::, 'collection', 'clear'
sync Collection::, 'insert', 'findOne', 'count', 'remove', 'update', 'ensureIndex', 'indexes', 'drop'
sync Cursor::, 'toArray', 'count'