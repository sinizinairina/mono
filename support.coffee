# Micon, dependency injector, will create global `app` variable.
Micon = require 'micon'
module.exports = app = new Micon()
app.app = app

# Printing.
app.p = console.log.bind console

# Logging.
app[name] = console[name].bind(console) for name in ['log', 'info', 'warn', 'error']

# Underscore.
app._ = require './underscore'

# Underscore for string.
app._s = require './underscore.string'

# Sync.
app.sync = require 'synchronize'