# Micon, dependency injector, will create global `app` variable.
Micon = require 'micon'
module.exports = app = new Micon()
app.app = app

# Printing.
app.p = console.log.bind console

# Logging.
withZero = (number) -> if number < 10 then "0#{number}" else number
removeNewlines = (list) ->
  (obj || 'null').toString().replace(/\n/g, "\\n") for obj in list
timestamp = ->
  date = new Date()
  "#{date.getFullYear()}/#{withZero(date.getMonth() + 1)}/#{withZero(date.getDate())}" +
  " #{withZero(date.getHours())}:#{withZero(date.getMinutes())}:#{withZero(date.getSeconds())}"
for name in ['log', 'info', 'warn', 'error']
  do (name) ->
    app[name] = (args...) ->
      # Formatting console messages according to use case, giving more details in production.
      if app.environment == 'development'
        if name == 'error' then console[name] args...
        else console[name] '  ', args...
      else
        args = removeNewlines args
        if name == 'error' then console[name] name, timestamp(), args...
        else console[name] '  ', timestamp(), args...

# Underscore.
app._ = require './underscore'

# Underscore for string.
app._s = require './underscore.string'

# Sync.
app.sync = require 'synchronize'

# User error.
UserError = (message) ->
  error = Error.call this, message
  error.name = "UserError"
  return error
UserError.prototype.__proto__ = Error.prototype
global.UserError = UserError