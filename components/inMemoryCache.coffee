inMemoryStorage = {}

module.exports =
  get   : (key) -> inMemoryStorage[key]
  set   : (key, value) -> inMemoryStorage[key] = value
  has   : (key) -> key of inMemoryStorage
  clear : -> inMemoryStorage = {}