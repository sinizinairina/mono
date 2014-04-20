{_} = require '../support'

module.exports = class Controller
  constructor: (app) ->
    @app = app
    {@request, @response} = @app

    @path     = @request._path
    @basepath = @request._basepath
    @params   = @request._params
    @body     = @request.body
    @format   = @request._format
    @session  = @request.session

  @layout = (templatePath) -> if templatePath? then @_layout = templatePath else @_layout

  parseCallbackOptions = (options = {}) ->
    options.only = [options.only] if options.only? and not _(options.only).isArray()
    options.except = [options.except] if options.except? and not _(options.except).isArray()
    options

  _(@).defineClassInheritableAccessor 'beforeCallbacks', []
  @before: (args...) ->
    [options, fn] = if _(args[0]).isString()
      methodName = args[0]
      [args[1], (-> @[methodName]())]
    else if args.length > 1 then args
    else [null, args[0]]
    _(fn).required('callback for before filter')
    @beforeCallbacks().push [fn, parseCallbackOptions(options)]

  _(@).defineClassInheritableAccessor 'afterCallbacks', []
  @after: (args...) ->
    [options, fn] = if _(args[0]).isString()
      methodName = args[0]
      [args[1], (-> @[methodName]())]
    else if args.length > 1 then args
    else [null, args[0]]
    _(fn).required('callback for after filter')
    @afterCallbacks().push [fn, parseCallbackOptions(options)]

  render: (args...) ->
    options  = if _(args[args.length - 1]).isObject() then args.pop() else {}
    template = args[0]

    # Responding with `/:className/:actionName` if there's no template.
    unless template and not options.nothing
      actionName = options.action || @actionName
      ClassName = @constructor.name
      className = "#{ClassName[0].toLowerCase()}#{ClassName[1..(ClassName.length - 1)]}"
      template = "/#{className}/#{actionName}"

    # Adding self to options.
    tmp = options
    options = {}
    options[k] = v for own k, v of @
    _(options).extend tmp

    # Layout.
    layout = if options.layout == false then false else options.layout || @constructor.layout()
    @response._renderWithLayout layout, template, options

  redirectTo: (args...) -> @response._redirectTo args...

  reloadPage: (args...) -> @response._reloadPage args...

  send: (args...) -> @response.send args...

  callAction: (actionName) ->
    @actionName = actionName

    unless actionName of @
      throw new Error "no '#{actionName}' in '#{@constructor.name}' controller!"

    unless _(@[actionName]).isFunction()
      throw new Error "'#{actionName}' in '#{@constructor.name}' controller isn't function!"

    isCallbackApplied = (options) ->
      if options.only? then (if actionName in options.only then true else false)
      else if options.except? then (if actionName not in options.except then true else false)
      else true

    # Executing before callbacks.
    for [fn, options] in @constructor.beforeCallbacks() when isCallbackApplied(options)
      try
        fn.call @
      catch obj
        # Stop execution if before calblack throws `break`.
        return if obj == 'break'
        throw obj

    # Executing action.
    @[actionName](@params)

    # Executing after callbacks.
    next = -> halt = false
    fn.call(@) for [fn, options] in @constructor.afterCallbacks() when isCallbackApplied(options)

  flash: (args...) ->
    throw new Error "no flash middleware!" unless @request.flash
    if _(args[0]).isObject() then @flash k, v for k, v of args[0]
    else @request.flash args...