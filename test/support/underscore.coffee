{_}    = require '../../support'
expect = require('chai').expect

describe "Underscore", ->
  it "should isolate inheritable accessors", ->
    class Base
      _(@).defineClassInheritableAccessor 'beforeCallbacks', []

    class ControllerA extends Base
      @beforeCallbacks().push 'a'

    class ControllerB extends Base
      @beforeCallbacks().push 'b'

    expect(Base.beforeCallbacks()).to.eql []
    expect(ControllerA.beforeCallbacks()).to.eql ['a']
    expect(ControllerB.beforeCallbacks()).to.eql ['b']

  it "should define class inheritable accessor", ->
    class Base
      _(@).defineClassInheritableAccessor 'beforeCallbacks', []
      @beforeCallbacks().push 'base'

    class ControllerA extends Base
      @beforeCallbacks().push 'a'

    expect(Base.beforeCallbacks()).to.eql ['base']
    expect(ControllerA.beforeCallbacks()).to.eql ['base', 'a']