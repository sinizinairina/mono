app = require '../../support'
app.environment = 'test'

# Pluralize leak globals, mocha complains, preventing it by preloading.
require 'natural'

global.async  = app.sync.asyncIt
global.expect = require('chai').expect

# Disabling logging.
for name in ['log', 'info', 'warn', 'error']
  app[name] = ->

# Factory.
app.factory = require './factory'

# Starting server.
before ->
  app.http.run()

beforeEach async ->
  # Preparing http client.
  Http = require './http'
  @http = new Http()

  # `app.factory.build` helper.
  # @build  = app.factory.build.bind(app.factory)
  # @create = app.factory.create.bind(app.factory)
  @factory = app.factory

# Clearing database before each test.
if app.environment == 'test'
  # Instead of clearing db before each test using smarter approach,
  # db will be cleared only if it's really used.
  cachedDb = null
  app.after 'db', (db) ->
    # Clearing db before it's used.
    db.clear()

    # Preventing full db initalization and using cached db.
    unless cachedDb
      cachedDb = db
      app.register 'db', scope: 'global', -> cachedDb

  afterEach -> app.unset 'db'
else console.warn "tests runned not in test environment, database not cleared!"