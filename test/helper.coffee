require '../support'
global.p = console.log.bind(console)

# Pluralize leak globals, mocha complains, preventing it by preloading.
require 'natural'

global.expect = require('chai').expect