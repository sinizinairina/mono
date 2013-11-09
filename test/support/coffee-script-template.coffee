{_}    = require '../../support'
expect = require('chai').expect
engine = require '../../support/coffee-script-template'

describe "CoffeeScript Template", ->
  it "should render", ->
    text = engine.compile("""
    data = <%= @name %>: 'value'
    """)(name: 'key')
    expect(text).to.match /key: 'value'/