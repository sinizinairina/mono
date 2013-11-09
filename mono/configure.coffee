path = require 'path'
app  = require '../support'

app.configure = (appFilePath, fn) ->
  # Setting application file path.
  app.appFilePath = path.resolve appFilePath

  # Setting some variables from environment.
  env = process.env
  app.assetFilePath  = env.assetFilePath                || "#{appFilePath}/assets"
  app.assetMountPath = env.assetMountPath               || '/assets'
  app.httpMountPath  = env.httpMountPath                || '/'
  app.port           = (env.port && parseInt(env.port)) || 3000
  app.host           = env.host                         || 'localhost'

  # Useful to emulate latency in UI.
  app.latency = (env.latency && parseInt(env.latency)) || 0

  fn?()