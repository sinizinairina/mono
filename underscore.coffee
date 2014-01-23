module.exports = _ = require 'underscore'
extend = require 'node.extend'

_.mixin
  # Handy shortcut for deleting property and returning its value.
  delete: (obj, key) ->
    oldValue = obj[key]
    if _(obj).isArray()
      obj.splice(key, 1) if (key >= 0) and (key < obj.length)
    else delete obj[key]
    oldValue

  # Handy shortcut for deleting property by value.
  deleteValue: (obj, value) -> @deleteIf obj, (v) -> v == value

  # Handy shortcut for deleting property by value.
  deleteIf: (obj, fn) ->
    if _(obj).isArray()
      indexes = (i for v, i in obj when fn(v))
      _.delete(obj, i) for i in indexes
    else
      keys = (k for k, v of obj when fn(v))
      delete obj[k] for k in keys

  # Checking if obj is null or empty collection or empty string.
  isBlank: (obj) ->
    return true if obj == null or obj == undefined
    return false if isFinite obj
    return obj.length == 0 if _.isArray obj
    return /^\s*$/.test obj if _.isString obj
    return false for own k of obj
    return true

  isPresent: (obj) -> !_.isBlank(obj)

  deepClone: (obj) ->
    if _(obj).isArray() then (extend(true, {}, o) for o in obj)
    else extend true, {}, obj

  defineClassInheritableAccessor: (obj, name, defaultValue) ->
    _name = "_#{name}"
    obj[name] = ->
      @[_name] ?= _(defaultValue).clone()
      @[_name] = _(@[_name]).clone() if @[_name] == @__super__?.constructor[_name]
      @[_name]

  required: (obj, name) ->
    throw new Error "'#{name}' required!" unless obj
    obj