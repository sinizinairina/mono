{_, _s} = require '../support'

module.exports = class Router
  route: (method, path, {action, controller, prefix}) ->
    throw new Error 'no method for route!' unless method
    throw new Error 'no path for route!' unless path
    throw new Error "no action for #{method}:#{path} route!" unless action
    throw new Error "no controller for #{method}:#{path} route!" unless action

    app = _(@app).required('app')
    path = "#{prefix}#{path}" if prefix
    path = "#{app.httpMountPath}#{path}" unless app.httpMountPath == '/'
    # Allowing to use `path.format`.
    path = "#{path}.:format?" if @useFormatPostfix
    app.http[method] path, (req, res, next) =>
      # Need try/catch block to prevent ExpressJs from intercepting errors.
      try
        app.http.prepareAfterRouter req, res
        @process controller, action
      catch err
        app.http.onError err, req, res, next

  configure: (fn) -> fn new Router.Dsl(@)

  process: (controller, action) ->
    app = _(@app).required('app')
    app.info "routing to #{controller}.#{action} as #{app.request._format}"

    klass = app[controller] || throw new Error "no '#{controller}' controller!"
    throw new Error "'#{controller}' isn't function!" unless _(klass).isFunction()

    app.controller = new klass(app)
    app.controller.callAction action

  _namedPath: (name, fn) ->
    app = _(@app).required('app')
    app[name] = fn

# DSL for building routes.
class Router.Dsl
  constructor: (@router) ->

  route    : (args...) => @router.route args...

  resource : (name, args...) =>
    fn      = args.pop() if _(args[args.length - 1]).isFunction()
    options = args[0] || {}

    resource = new Router.Dsl.Resource(@router, [name], options)
    fn? resource

# Resource.
class Router.Dsl.Resource
  @commonActions = ['index', 'create', 'show', 'update', 'destroy']

  constructor: (@router, @names, options) ->
    @names = _(names).clone()
    @name    = names.pop()
    @parents = ([name, _s.isPlural(name), _s.singularize(name)] for name in names)

    withOptions = (opts) -> _(opts).extend options

    if _s.isPlural @name
      # Plural resource.
      @collection 'get',    withOptions action: 'index'
      @collection 'get',    withOptions action: 'new', singularNamedPath: true
      @collection 'post',   withOptions action: 'create'
      @member     'get',    withOptions action: 'show'
      @member     'get',    withOptions action: 'edit'
      @member     'put',    withOptions action: 'update'
      @member     'delete', withOptions action: 'destroy'
    else
      # Singular resource.
      @collection 'get',    withOptions action: 'show'
      @collection 'get',    withOptions action: 'new'
      @collection 'post',   withOptions action: 'create'
      @collection 'get',    withOptions action: 'edit'
      @collection 'put',    withOptions action: 'update'
      @collection 'delete', withOptions action: 'destroy'

  member     : (method, options) -> @_add 'member', method, options
  collection : (method, options) -> @_add 'collection', method, options

  resource : (name, args...) ->
    fn      = args.pop() if _(args[args.length - 1]).isFunction()
    options = args[0] || {}

    names = _(@names).clone()
    names.push name
    resource = new Router.Dsl.Resource(@router, names, options)
    fn? resource

  _add: (type, method, options = {}) ->
    [name, parents] = [@name, @parents]
    that = @

    action         = options.action
    isCommonAction = action in Router.Dsl.Resource.commonActions

    [pluralName, singularName] = if _s.isPlural name then [name, _s.singularize(name)]
    else [_s.pluralize(name), name]

    humanizedName         = _s.humanize name
    humanizedPluralName   = _s.humanize pluralName
    humanizedSingularName = _s.humanize singularName

    # Adding prefixes for nested resources.
    pathPrefixParts = []
    prefixIdIndexes = []
    prefixIdNames   = []
    for [parentName, isPlural, singularParentName], i in parents
      if isPlural
        idName = "#{singularParentName}Id"
        pathPrefixParts.push "/#{parentName}/", ":#{idName}"
        prefixIdIndexes.push i * 2 + 1
        prefixIdNames.push idName
      else pathPrefixParts.push "/#{parentName}"

    addPathPrefix = (path) ->
      "#{pathPrefixParts.join('')}#{path}"

    addNamedPathPrefix = (action, isCommonAction, path) ->
      parts = []
      addPart = (part) ->
        if parts.length == 0 then parts.push part
        else parts.push _s.humanize(part)
      parts.push action unless isCommonAction
      addPart(options.namedRoutePrefix) if options.namedRoutePrefix
      addPart(singularParentName) for [parentName, isPlural, singularParentName] in parents
      addPart path
      parts.join('')

    addNamedPathFnPrefix = (namedPath, fnWithoutPrefix) ->
      if parents.length == 0
        ->
          [path, params] = fnWithoutPrefix.apply(null, arguments)
          path = "#{options.prefix}#{path}" if options.prefix
          that.router.app.path path, params
      else
        ->
          # Building prefix.
          parts = _(pathPrefixParts).clone()
          index = 0
          for prefixIdIndex in prefixIdIndexes
            unless (id = arguments[index])?
              throw new Error "no '#{prefixIdNames[index]}' for '#{namedPath}'!"
            parts[prefixIdIndex] = id.id || id
            index += 1

          # Creating args without prefix.
          args = []
          args.push(arg) for arg, i in arguments when i >= prefixIdIndexes.length

          # Calling named path without prefix.
          [path, params] = fnWithoutPrefix.apply(null, args)

          # Joining prefix and path.
          parts.push path
          path = parts.join('')

          # Adding prefix.
          path = "#{options.prefix}#{path}" if options.prefix

          that.router.app.path path, params

    namedPath = if options.singularNamedPath or type == 'member' then singularName else name
    namedPath = addNamedPathPrefix action, isCommonAction, namedPath
    namedPath = "#{namedPath}Path"

    options = _(options).clone()
    options.controller ?= humanizedName

    if type == 'collection'
      # Same for plural and singular.
      routePath = if isCommonAction then "/#{name}" else "/#{name}/#{action}"
      routePath = addPathPrefix routePath
      @router.route method, routePath, options
      if isCommonAction
        @router._namedPath namedPath, addNamedPathFnPrefix namedPath, (params) ->
          ["/#{name}", params]
      else
        @router._namedPath namedPath, addNamedPathFnPrefix namedPath, (params) ->
          ["/#{name}/#{action}", params]
    else if type == 'member'
      routePath = if isCommonAction then "/#{name}/:id" else "/#{name}/:id/#{action}"
      routePath = addPathPrefix routePath
      @router.route method, routePath, options
      noId = -> throw new Error "no 'id' for '#{namedPath}'!"
      if isCommonAction
        @router._namedPath namedPath, addNamedPathFnPrefix namedPath, (id, params) ->
          ["/#{name}/#{(id && id.id) || id || noId()}", params]
      else
        @router._namedPath namedPath, addNamedPathFnPrefix namedPath, (id, params) ->
          ["/#{name}/#{(id && id.id) || id || noId()}/#{action}", params]
    else throw new Error "unknown type '#{type}'!"

# Add HTTP werb to router DSLs, use it to add custom werbs.
Router.addWerb = (werb) ->
  fn = (args...) -> @route werb, args...
  Router.Dsl::[werb] = fn

Router.addWerb werb for werb in ['get', 'post', 'put', 'del', 'delete']