{_, _s} = require '../support'

module.exports = ->
  helpers = {}

  helpers.escapeAttributes = (attrs) ->
    unless attrs.safe
      tmp = attrs
      attrs = {}
      attrs[@escape(n)] = @escape(v) for n, v of tmp
    attrs

  helpers.tag = (name, attrs = {}, content = '') ->
    isFunction = _(content).isFunction()
    content = content() if isFunction

    attrs   = @escapeAttributes attrs
    content = @escape content unless attrs.safe

    parts = []
    parts.push "<#{name}"
    parts.push " #{n}=\"#{v}\"" for n, v of attrs when n != 'safe' if attrs
    parts.push ">"
    parts.push content
    parts.push "</#{name}>"
    html = parts.join('')
    if isFunction then @safe html else html

  helpers.link = (title, link, attrs = {}) ->
    # Handling some attributes specially.
    attrs = _(attrs).clone()
    for name in ['method', 'confirm', 'form', 'remote']
      if value = attrs[name]
        attrs["data-#{name}"] = value
        delete attrs[name]
    attrs.href = link
    @tag 'a', attrs, title

  helpers.basicJs = ->
    unless @_basicJs
      fs = require 'fs'
      js = fs.readFileSync require.resolve('./helpers/basic.js')
      @_basicJs = """<script type="text/javascript">#{js}</script>"""
    @_basicJs

  helpers.pluralize = (count, singular, plural) ->
    "#{count} " + (if count == 1 then singular else plural || _s.pluralize(singular))

  helpers.render = (template, options) ->
    _(@).extend options
    _(@app).required('app').render.renderWithContext template, @

  helpers.errorMessages = (errors, options = {}) ->
    list = []
    for attr, messages of errors
      attr = options.replace?[attr] || attr
      for message in messages
        if attr == 'base' then list.push _s.humanize message
        else list.push "#{_s.humanize(attr)} #{message}"
    list

  helpers.flash = (args...) ->
    throw new Error "no flash middleware!" unless @request.flash
    @request.flash args...

  helpers.formTag = (attrs = {}, content = '') ->
    isFunction = _(content).isFunction()

    # Handling `method` attribute specially.
    parts = []
    if (method = attrs.method) and method not in ['get', 'post']
      attrs.method = 'post'
      parts.push @tag 'input', name: '_method', value: method, type: 'hidden'

    parts.push if isFunction then content() else content

    attrs = @escapeAttributes _(attrs).clone()
    attrs.safe = true

    html = @tag 'form', attrs, parts.join('')

    if isFunction then @safe(html) else html

  helpers.contentFor = (variableName, fn) -> @[variableName] = fn()

  helpers.capture = (fn) -> fn()

  helpers.renderAsString = (args...) -> JSON.stringify @render args...

  helpers