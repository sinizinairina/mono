app = require '../support'

_destroyIfNotDestroyedAndRemoveIfNotRemoved = (name, actor, version) ->
  # Removing from list of actors before destroying because `destroy` may be asynchronous
  # and violate atomicy.
  [currentActor, tmp...] = app.actors[name]
  delete app.actors[name] if actor == currentActor

  try
    unless actor.isDestroyed()
      # We need to make sure this logic is atomic and destroy may have fiber code.
      app.sync.fiber -> actor.destroy()
  catch err
    app.error "can't destroy '#{name}' v. #{version} actor\n#{err.stack}!"

app.actors = {}
app.actorsVersions = {}
app.activate = (name, actor, args...) ->
  cb = args.pop() if _(args[args.length - 1]).isFunction()
  options = args[0] || {}

  for fname in ['act', 'destroy', 'isDestroyed']
    unless _(actor[fname]).isFunction()
      throw new Error "actor '#{name}' doesn't have `#{fname}` method!"

  if name of app.actors
    [currentActor, messages, version] = app.actors[name]
    if options.replace
      app.info "actor '#{name}' v. #{version} already exists and will be replaced"
      _destroyIfNotDestroyedAndRemoveIfNotRemoved name, currentActor, version
    else throw new Error "actor '#{name}' v. #{version} already exists!"

  app.actorsVersions[name] ?= 0
  app.actorsVersions[name] += 1

  # Registering actor.
  messages = []
  version = app.actorsVersions[name]
  app.actors[name] = [actor, messages, version]

  # Starting fiber.
  app.sync.fiber ->
    app.info "actor '#{name}' v. #{version} started"
    while true
      if actor.isDestroyed()
        _destroyIfNotDestroyedAndRemoveIfNotRemoved name, actor, version
        app.info "actor '#{name}' v. #{version} stopped"
        break

      try
        timeout = if messages.length > 0
          [method, args] = messages.shift()
          actor[method].apply(actor, args)
          null
        else actor.act()
      catch err
        app.error "actor '#{name}' v. #{version} threw error and will be destroyed\n#{err.stack}!"
        _destroyIfNotDestroyedAndRemoveIfNotRemoved name, actor
        return

      if timeout == false then return
      else if timeout > 0
        defer = app.sync.defer()
        setTimeout (-> defer()), timeout
        app.sync.await()
      else
        defer = app.sync.defer()
        process.nextTick (-> defer())
        app.sync.await()
  , cb

app.send = (name, method, args...) ->
  throw new Error "no actor with '#{name}'!" unless name of app.actors
  [actor, messages] = app.actors[name]
  messages.push([method, args])