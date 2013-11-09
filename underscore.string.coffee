module.exports = _s = require 'underscore.string'

_s.unicodeAz = "\u0080-\u9999"
_s.escapeHashInUrl = (url) -> url.replace '#', '%23'
_s.unescapeHashInUrl = (url) -> url.replace '%23', '#'

_s.nounInflector = ->
  @_nounInflector = new (require('natural').NounInflector)()

_s.pluralize = (str) -> @nounInflector().pluralize str
_s.singularize = (str) -> @nounInflector().singularize str
_s.isPlural = (str) -> !_s.isSingular(str)
_s.isSingular = (str) -> str == _s.singularize(str)