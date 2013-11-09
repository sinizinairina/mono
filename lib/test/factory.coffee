class Factory
  next: (->
    counter = 0
    -> counter += 1; counter
  )()

  toToken: (str) -> str.toString().replace(/[^a-zA-Z0-9-]/g, '-')

  toId: (str) -> toToken(str).toLowerCase() + '-id'

  # build: (name, attrs = {}) ->
  #   @[name](attrs)
  #
  # create : (name, attrs = {}) ->
  #   model = @build(name, attrs)
  #   model.create() || throw new Error "can't create '#{name}'!"
  #   model

module.exports = new Factory()