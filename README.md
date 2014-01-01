q-di
====

Minimalistic dependency injection capable of handling asynchronous dependencies (using the promise library [Q](http://github.com/kriskowal/q)). Some inspiration drawn from the Java DI frameworks [Guice](https://code.google.com/p/google-guice/) and [Dagger](http://square.github.io/dagger/).

## How to use

A set of dependencies (henceforth referred to as a "module") is specified via a Javascript object. Each dependency is a named function, where the arguments to the function specify the prerequisite dependencies that must be satisfied before the dependency itself can be satisfied. A module for a hypothetical server might look like (source code in [CoffeeScript](http://coffeescript.org/) for succinctness):

```coffee
MODULE = {
  server  : (cache, database) -> new MyServer(cache, database)
  cache   : -> new MyCache()
  database: -> new MyDatabase()
}
```

Here we see that constructing a `server` object depends on first constructing a `cache` object and a `database` object. To actually construct a `server` object, we need to create an `Injector` and call the correspondingly named function on it:

```coffeescript
di = require('q-di')
injector = new di.Injector(MODULE)
injector.server() # construct a server (returns a Q promise)
```

### Promises/asynchrony

Most importantly, dependencies can return promises instead of raw values. For example, the following module introduces a 100 ms delay when constructing a `foo` object:

```coffeescript
MODULE = {
  foo : -> Q.delay(100).then(-> 'foo')
}

# Prints "foobar" (after 100 ms):
new di.Injector(MODULE).foo().done((result) -> console.log(result))
```

The above example is contrived, but more realistically, some of your components may need to perform IO asynchronously before they are fully initialized. For example, you might want to define a module where the `server` object depends on a `database` object which needs to first establish a connection to the database before it's initialized.

That's the entire API!

## Notes

### Constants

Dependencies can be specified as constants instead of functions. The following is a valid module specification:

```coffeescript
MODULE = {
  foo : 'foo' # constant
  bar : (foo) -> foo + 'bar'
}
```

### Scoping

All constructed objects are singleton-scoped to the injector. This means that calling a method on an injector multiple times will return the same instance of the object (actually, promise), e.g. the following returns true:

```coffeescript
injector.foo() == injector.foo() # always equal
```

Objects are not shared across injectors, however, e.g. if injector1 and injector2 are separate objects:

```coffeescript
injector1.foo() != injector2.foo() # never equal
```

### Cycles

Cyclic dependencies will result in an error being thrown, e.g. the following fails:

```coffeescript
new di.Injector({ foo: (foo) -> }).foo() # throws error
```

### Promise coercion

The Q library is compatible with many other promise implementations (as long as they follow the [Promises/A+ specification](http://promises-aplus.github.io/promises-spec/)). This means module dependencies may return non-Q promises. Note, however, that the injector will always coerce such promises into Q promises.
