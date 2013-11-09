exports.compile = (data) ->
  # Removing template tokens because it's not valid CoffeeScript.
  tokens = []
  data = data.replace /(<%[^<%>]+%>)/g, (token) ->
    tokens.push token
    "__token#{tokens.length - 1}__"

  # Compiling CoffeeScript to JavaScript.
  data = require('coffee-script').compile data

  # Putting template tokens back.
  for token, i in tokens
    data = data.replace "__token#{i}__", token

  # Compiling as eco template.
  require('eco').compile data