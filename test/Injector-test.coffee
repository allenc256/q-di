assert   = require('assert')
Q        = require('q')
Injector = require('../lib').Injector

describe 'Injector', ->
  it 'raw value provider function works', (done) ->
    new Injector({ foo: -> 123 }).foo().done (v) ->
      assert.equal(123, v)
      done()

  it 'promise provider function works', (done) ->
    new Injector({ foo: -> Q(123) }).foo().done (v) ->
      assert.equal(123, v)
      done()

  it 'provider function with dependencies works', (done) ->
    new Injector({
      foo : -> 'foo'
      bar : -> Q('bar')
      baz : (foo, bar) -> foo + bar
    }).baz().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'full specification works', (done) ->
    new Injector({ 
      foo:
        deps   : ['bar']
        create : (bar) -> 'foo' + bar
      bar:
        deps   : []
        create : -> 'bar'
    }).foo().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'asynchronous dependencies work', (done) ->
    new Injector({
      foo : -> Q.delay(10).then -> 'foo'
      bar : -> Q.delay(50).then -> 'bar'
      baz : (foo, bar) -> foo + bar
    }).baz().done (v) ->
      assert.equal('foobar', v)
      done()

  it 'transitive dependencies work', (done) ->
    i = new Injector({
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
    i = new Injector({
      foo : -> {}
    })
    Q.all([i.foo(), i.foo()])
    .done ([foo1, foo2]) ->
      assert.equal(foo1, foo2)
      done()

  it 'errors gracefully on invalid dependencies', (done) ->
    try
      new Injector({
        foo : (bar) -> 'foo' + bar
        bar : (baz) -> 'bar' + baz
      }).foo()
    catch err
      assert.equal('Missing specification for dependency: baz', err.message)
      return done()
    done('expected Error')

  it 'errors gracefully on cycles', (done) ->
    try
      new Injector({
        foo : (foo) -> foo + 'foo'
      }).foo()
    catch err
      assert.equal('Cycle detected', err.message)
      return done()
    done('expected Error')

  it 'errors gracefully on cycles 2', (done) ->
    try
      new Injector({
        foo : (bar) -> 'foo' + bar
        bar : (baz) -> 'bar' + baz
        baz : (foo) -> 'baz' + foo
      }).foo()
    catch err
      assert.equal('Cycle detected', err.message)
      return done()
    done('expected Error')
