module.exports = app = require './support'
require './mono/actor'
require './mono/command'
require './mono/configure'
require './mono/http'

app.register 'render', -> require('./components/render')()
app.register 'helpers', -> require('./components/helpers')()

app.register 'Http', -> require './components/Http'
app.register 'http', -> app.Http()

app.register 'Router', -> require './components/Router'
app.register 'router', -> new app.Router()

app.register 'HttpController', -> require './components/HttpController'

app.register 'controller', scope: 'fiber'

app.register 'request', scope: 'fiber'
app.register 'response', scope: 'fiber'

app.register 'Model', ->
  Model = require 'micromodel'
  {ModelPersistence} = require 'micromodel/mongodb'
  ModelPersistence Model
  Model.db = -> app.db
  Model

app.register 'db', scope: 'global', ->
  {MongoClient} = require 'micromodel/mongodb'
  throw new Error "not defined app.dbPath!" unless app.dbPath
  MongoClient.connect app.dbPath, app.sync.defer()
  app.sync.await()