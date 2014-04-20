# Rendering.
{_} = require '../support'
fs2 = require '../fs2'

module.exports = ->
  render = (path, options = {}) ->
    context = render.buildContext options
    render.renderWithContext path, context

  render.directories = []

  render.withLayout = (layout, path, options = {}) ->
    context = render.buildContext options
    content = if options.nothing then '' else render.renderWithContext(path, context)
    if layout
      context.content = content
      content = render.renderWithContext layout, context
    content

  render.renderWithContext = (path, context) ->
    app = _(@app).required('app')
    key = "#{path}:#{context.format}"
    if not (template = render.templates[key]) or (app.environment == 'development')
      # Assemgling list of path to try.
      tryPaths = []

      # Resolving relative paths to absolute.
      absolutePaths = if context.absolutePath then [path]
      else
        if render.directories.length == 0
          throw new Error "no template paths registered for '#{app}'!"
        ("#{directory}#{path}" for directory in render.directories)

      # Resolving format and rendering engine.
      for absolutePath in absolutePaths
        # Trying paths with explicit format first.
        if format = context.format
          # Trying all formats (try also `coffee` for `js`).
          formats = render.formatFamilies[format] || [format]
          for format in formats
            # With explicit template extension.
            for extension, engine of render.engines
              tryPaths.push "#{absolutePath}.#{format}.#{extension}"

            # Without template extension.
            tryPaths.push "#{absolutePath}.#{format}"

        # Trying paths without format.
        # With explicit template extension.
        for extension, engine of render.engines
          tryPaths.push "#{absolutePath}.#{extension}"

        # Without template extension.
        tryPaths.push absolutePath

      # Searching template.
      [data, found] = [null, false]
      for tryPath in tryPaths
        try
          data = fs2.readFile(tryPath, 'utf8')
          found = true
          break
        catch err
      throw new Error "no template '#{path}'!" unless found

      # Detecting engine by extension.
      extension = if (parts = tryPath.split('.')).length > 1 then _(parts).last() else null
      engine    = render.engines[extension] || render.defaultEngine

      template = engine data
      render.templates[key] = template
    template context

  # Template engines and extensions.
  eco      = (source) -> require('eco').compile source
  coffee   = (source) -> require('../support/coffee-script-template').compile source
  mustache = (source) ->
    template = require('hogan.js').compile source
    (data) -> template.render data

  render.defaultEngine = eco
  render.engines =
    html   : eco
    coffee : coffee
    js     : eco
    eco    : eco
    json   : eco
    ms     : mustache
    xml    : eco

  render.formatFamilies =
    html : ['html']
    js   : ['js', 'coffee']
    json : ['json', 'js', 'coffee']
    xml  : ['xml']

  render.templates = {}

  # Creates render context.
  render.buildContext = (options) ->
    app = _(@app).required('app')
    _({}).extend app.helpers, options

  render