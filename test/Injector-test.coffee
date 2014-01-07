assert = require('assert')
Q      = require('q')
di     = require('../lib')

describe 'Injector', ->
  it 'raw value provider function works', (done) ->
    new di.Injector({ foo: -> 123 }).foo().done (v) ->
      assert.equal(123, v)
      done()

  it 'promise provider function works', (done) ->
    new di.Injector({ foo: -> Q(123) }).foo().done (v) ->
      assert.equal(123, v)
      done()

  it 'provider function with dependencies works', (done) ->
    new di.Injector({
      foo : -> 'foo'
      bar : -> Q('bar')
      baz : (foo, bar) -> foo + bar
    }).baz().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'full specification works', (done) ->
    new di.Injector({ 
      foo:
        args   : ['bar']
        create : (bar) -> 'foo' + bar
      bar:
        args   : []
        create : -> 'bar'
    }).foo().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'asynchronous dependencies work', (done) ->
    new di.Injector({
      foo : -> Q.delay(10).then -> 'foo'
      bar : -> Q.delay(50).then -> 'bar'
      baz : (foo, bar) -> foo + bar
    }).baz().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'transitive dependencies work', (done) ->
    i = new di.Injector({
      foo : (bar) -> 'foo' + bar
      bar : (baz) -> 'bar' + baz
      baz : -> 'baz'
    })
    Q.all([i.foo(), i.bar(), i.baz()])
    .done ([foo, bar, baz]) ->
      assert.equal('foobarbaz', foo)
      assert.equal('barbaz', bar)
      assert.equal('baz', baz)
      done()

  it 'constructs singleton-scoped objects', (done) ->
    i = new di.Injector({
      foo : -> {}
    })
    Q.all([i.foo(), i.foo()])
    .done ([foo1, foo2]) ->
      assert.equal(foo1, foo2)
      done()

  it 'errors gracefully on invalid dependencies', (done) ->
    try
      new di.Injector({
        foo : (bar) -> 'foo' + bar
        bar : (baz) -> 'bar' + baz
      }).foo()
    catch err
      assert.equal('Missing specification for dependency: baz', err.message)
      return done()
    done('expected Error')

  it 'errors gracefully on cycles', (done) ->
    try
      new di.Injector({
        foo : (foo) -> foo + 'foo'
      }).foo()
    catch err
      assert.equal('Cycle detected', err.message)
      return done()
    done('expected Error')

  it 'errors gracefully on cycles 2', (done) ->
    try
      new di.Injector({
        foo : (bar) -> 'foo' + bar
        bar : (baz) -> 'bar' + baz
        baz : (foo) -> 'baz' + foo
      }).foo()
    catch err
      assert.equal('Cycle detected', err.message)
      return done()
    done('expected Error')

  it 'namespacing works', (done) ->
    fooCreate = (bar) -> 'foo' + bar
    barCreate = -> 'bar'

    # Namespace with function deps
    actual1 = di.namespace('prefix.', {
      foo : fooCreate
      bar : barCreate
    })
    # Namespace with explicit argument deps
    actual2 = di.namespace('prefix.', {
      foo :
        args   : ['bar']
        create : fooCreate
      bar :
        args   : []
        create : barCreate
    })
    expected = {
      'prefix.foo' :
        args   : ['prefix.bar']
        create : fooCreate
      'prefix.bar' :
        args   : []
        create : barCreate
    }

    assert.deepEqual(expected, actual1)
    assert.deepEqual(expected, actual2)
    new di.Injector(actual1)['prefix.foo']().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'private dependencies', (done) ->
    injector = new di.Injector({
      foo: 
        args   : ['bar']
        create : (bar) -> 'foo' + bar
      bar:
        private : true
        create  : -> 'bar'
    })
    assert.ok(injector.foo?)
    assert.ok(not injector.bar?)
    injector.foo().done (v) ->
      assert.equal('foobar', v)
      done()

