# Redirect from www.
module.exports = (app) ->
  (req, res, next) ->
    if /^www/.test(req.host)
      protocol = if req.connection.encrypted then 'https' else 'http'
      # Sometimes express returns host with port, not allowing it.
      throw new Error("express returns host with port!") if /:[0-9]/.test hostWithoutWww
      hostWithoutWww = req.host.replace 'www.', ''
      urlWithoutWww = app.buildUrl req.path, protocol: protocol, host: hostWithoutWww
      , port: app.port
      return res.redirect 301, urlWithoutWww
    else next()
