{_}     = require '../support'
express = require 'express'
{mime}  = express

# Helpers.
splitPath = (fullPath) ->
  if match = /\.([a-z0-9]+)$/i.exec(fullPath)
    extension = match[1]
    path = fullPath[0..(fullPath.length - 1 - 1 - extension.length)]
    [path, extension]
  else
    [fullPath, null]

# Http.
module.exports = Http = ->
  http = express()

  http.express = express

  # # Error handling.
  # http.use (err, req, res, next) -> res.send err.message

  http.prepare = ->
    app = _(@app).required('app')
    (req, res, next) ->
      # Updating request.
      req._path = decodeURI req.path

      # Merging different params into one.
      req._params = _({}).extend req.params, req.body, req.query

      # Splitting path into base and extension.
      [req._basepath, req._extension] = splitPath req._path

      # Setting format for request.
      if (format = req.query.format)? then req._format = format
      else
        for format of http.formats when req.is format
          req._format = name
          break
      req._format ?= http.defaultFormat

      # Setting format for response.
      res._setFormat req._format

      # Starting fiber.
      app.sync.fiber ->
        try
          app.scope 'request', ->
            # express request and response already have `app` variable,
            # preventing micon from overriding it (it sets `app` reference to self
            # on every component).
            # And setting `_app` as reference to micon.
            req._app    = app
            reqApp      = req.app
            app.request = req
            req.app     = reqApp

            res._app     = app
            resApp       = res.app
            app.response = res
            res.app      = resApp

            next()
        catch err
          http.onError err, req, res, next

  # Some information available only when routing is finished, updating.
  http.prepareAfterRouter = (req, res) ->
    # Explicit format overrides content settings.
    if (format = req.params.format)?
      req._format = format
      res._setFormat format
    _(req._params).extend req.params

  http.logger = ->
    (req, res, next) ->
      unless /\/favicon.ico$/.test req.path
        msg = []
        msg.push "http #{req.method.toLowerCase()} #{req.path}"
        # Don't logging json body in production.
        if app.environment != 'production'
          body = JSON.stringify(req.body)?.replace(/"([^"]+)":/g, '$1: ') \
          .replace(/(["\]\}]),/g, '$1, ')
          body = body[0..197] + '...' if body.length > 200
          msg.push "with #{body}" if body != '{}'
        else if req.body? then msg.push "with body '...'"
        app.info msg.join(' ')
      next()

  http.defaultFormat = 'html'
  http.formats = ['html', 'json', 'js', 'xml']

  # Run http server.
  http.run = ->
    {port, brand, host, environment} = _(@app).required('app')
    @listen port
    msg = []
    msg.push "#{brand} started on #{host}:#{port} with #{environment} environment"
    msg.push ", with latency #{app.latency} ms" if app.latency > 0
    @app.info msg.join('')

  http.useCommonMiddleware = ->
    app = _(@app).required('app')

    @use express.compress()

    if app.assetMountPath
      maxAge = app.assetMaxAge || 31557600000
      @use app.assetMountPath, express.static(app.assetFilePath, maxAge: maxAge)

    @use express.cookieParser()

    # Not using `bodyParser` and using `json, urlencoded, multipart` because
    # `jsonLimit` and `fileLimit` may be different.
    # @use express.bodyParser()
    @use express.json limit: app.jsonLimit
    @use express.urlencoded()
    @use express.multipart limit: app.fileLimit

    @use express.methodOverride()

    if app.sessionKey?
      @use express.cookieSession
        key    : (app.sessionKey    || throw new Error "`app.sessionKey` not defined!")
        secret : (app.sessionSecret || throw new Error "`app.sessionSecret` not defined!")

    @use require('../lib/express/flash')()
    @use require('../lib/express/nowww')(app)

    @use @logger()

    @use @emulateLatency(app.latency, app.log) if app.latency > 0

    @use http.prepare()

  http.onError = (err, req, res, next) ->
    @_expressErrorHandler ?= express.errorHandler()
    @_expressErrorHandler err, req, res

  http.emulateLatency = (latency) ->
    app = _(@app).required('app')
    (req, res, next) ->
      if latency > 0
        delay = Math.floor(Math.random() * 2 * app.latency)
        app.info "delaying #{req.path} for #{delay} ms"
        setTimeout next, delay
      else next()

  http

ResponseMixin = (res) ->
  res._setFormat = (format) ->
    @_format = format
    if contentType = mime.lookup(format || '')
      # if format == 'json' and !/charset/i.test(contentType)
      #   contentType = "#{contentType}; charset=utf-8"
      @set 'Content-Type', contentType

  res.sendWithoutJsonFormat = res.send
  res.send = (args...) ->
    if args.length == 0 and @_format == 'json' then @sendWithoutJsonFormat({})
    else @sendWithoutJsonFormat args...

  res._renderWithLayout = (layout, template, options) ->
    # Setting responce format if provided explicitly.
    @_setFormat options.format if options.format

    # Rendering.
    app = _(@_app).required('app')
    content = app.render.withLayout layout, template, options

    # Responding.
    @send content

  res._redirectTo = (args...) ->
    switch @_format
      when 'js'
        @send """
          // Allowing client to setup custom __redirectTo.
          if(typeof __redirectTo != "undefined") __redirectTo("#{args[0]}");
          else window.location.href = "#{args[0]}";
        """
      when 'json' then @send JSON.stringify {location: args[0]}, null, 2
      else @redirect args...

  res._reloadPage = (args...) ->
    switch @_format
      when 'js'
        @send """
          // Allowing client to setup custom __reloadPage.
          if(typeof __reloadPage != "undefined") __reloadPage();
          else window.location.reload();
        """
      else throw new Error "refresh not supported for '#{@_format}' format!"
  res

ResponseMixin express.response