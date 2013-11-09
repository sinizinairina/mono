app = require '../../support'

module.exports = Http = -> @initialize.apply(@, arguments); @

Http::initialize = ->

Http::call = (method, path, dataOptions..., callback) ->
  method  = method.toLowerCase()
  data    = dataOptions[0]
  options = dataOptions[1] || {}
  options.format ?= app.http.defaultFormat

  # Request.
  reqOptions =
    host    : app.host
    port    : app.port
    path    : path
    method  : method
    headers :
      'Content-Type' : Http.contentType(options.format, method)

  # Serializing data.
  if data?
    unless serializer = Http.formats[options.format]
      throw new Error "no serializer for '#{options.format}' format!"
    data = serializer data
    reqOptions.headers['Content-Length'] = data.length

  # Sending request.
  nodeHttp = require 'http'
  req = nodeHttp.request reqOptions, (res) ->
    res.setEncoding 'utf8'
    resData = []
    res.on 'data', (chunk) -> resData.push chunk
    res.on 'end', ->
      resData = resData.join()
      if /json/.test res.headers['content-type']
        resData = try JSON.parse resData catch err then "can't parse '#{resData}'"
        callback null, status: res.statusCode, headers: res.headers, data: resData
      else
        callback null, status: res.statusCode, headers: res.headers, data: resData
  req.on 'error', callback

  req.write data if data?
  req.end()

Http::get    = (args...) -> @call 'get', args...
Http::post   = (args...) -> @call 'post', args...
Http::put    = (args...) -> @call 'put', args...
Http::delete = (args...) -> @call 'delete', args...
Http::del    = (args...) -> @call 'delete', args...

Http.contentType = (format, method) ->
  return 'application/x-www-form-urlencoded' if format == 'html' and method != 'get'
  {mime} = require 'express'
  mime.lookup format

Http.formats =
  html: (data) -> require('querystring').stringify data
  json: (data) -> JSON.stringify data, null, 2

app.sync Http::, 'call', 'get', 'post', 'put', 'delete'