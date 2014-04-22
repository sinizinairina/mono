app = require '../support'

app.actors = {}
app.activate = (name, actor, cb) ->
  for fname in ['act', 'destroy', 'isDestroyed']
    unless _(actor[fname]).isFunction()
      throw new Error "actor '#{name}' doesn't have `#{fname}` method!"
  throw new Error "actor with '#{name}' name already exists!" if name of app.actors

  messages = []
  app.actors[name] = [actor, messages]

  app.sync.fiber ->
    app.info "actor '#{name}' started"
    while !actor.isDestroyed()
      try
        timeout = if messages.length > 0
          [method, args] = messages.shift()
          actor[method].apply(actor, args)
          null
        else actor.act()
      catch err
        app.error "actor '#{name}' threw error and will be destroyed\n#{err.stack}!"

        # Removing from list of actors before destroying because `destroy` may be asynchronous
        # and violate atomicy.
        delete app.actors[name]

        try
          actor.destroy()
          app.info "actor '#{name}' destroyed"
        catch err
          app.error "can't destroy '#{name}' actor\n#{err.stack}!"
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