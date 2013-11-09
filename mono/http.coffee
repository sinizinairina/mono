{_, app} = require '../support'

# Path helpers.
app.buildUrl = (path, params={}) ->
  # Rejecting empty pareters.
  oldParams = params
  params    = {}
  params[k] = v for k, v of oldParams when k? and v?

  # Processing `host`, `port`, `protocol` and `format` specially.
  if params.host
    host = params.host
    delete params.host
  if params.port
    port = params.port
    delete params.port
  if params.protocol
    protocol = params.protocol
    delete params.protocol
  else
    protocol = 'http'

  # if params.format == 'http'
  #   format = params.format
  #   delete params.format
  # else
  #   format = 'html'

  # Building url.
  # path = encodeURI path
  if host
    portStr = if port and port != 80 and port != '80' then ':' + port else ''
    path = "#{protocol}://#{host}#{portStr}#{if path == '/' then '' else path}#{}"

  # path = "#{path}.#{format}" if format != 'html'

  if _(params).size() > 0
    delimiter = if /\?/.test(path) then '&' else '?'
    buff = []
    for k, v of params
      buff.push "#{encodeURIComponent(k.toString())}=#{encodeURIComponent(v.toString())}"
    path + delimiter + buff.join('&')
  else
    path

app.path = (path, params) ->
  prefix = @httpMountPath || '/'
  @buildUrl "#{if prefix == '/' then '' else prefix}#{path}", params

app.assetPath = (path = '', params = {}) ->
  prefix = @assetMountPath || '/'
  @buildUrl "#{if prefix == '/' then '' else prefix}#{path}", params