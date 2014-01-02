Q = require 'q'

# http://stackoverflow.com/questions/1007981
STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;
getParamNames = (fn) ->
  fnStr  = fn.toString().replace(STRIP_COMMENTS, '')
  result = fnStr.slice(fnStr.indexOf('(')+1, fnStr.indexOf(')')).match(/([^\s,]+)/g)
  return result || []

# The dependency injection engine.
class Builder
  constructor: (module) ->
    # Cache for built objects.
    @built    = {}
    # Specification for how to build objects.
    @specs    = {}
    # Max depth used to perform cycle detection.
    @maxDepth = 0

    for own k, v of module
      if v instanceof Function
        @maxDepth++
        @specs[k] = {
          dependencies : getParamNames(v)
          provider     : v
        }
      else
        @built[k] = Q(v)

  build: (k, depth = 0) ->
    return @built[k] if @built[k]

    throw new Error('Cycle detected') if depth > @maxDepth

    spec = @specs[k]
    throw new Error("Missing specification for dependency: #{k}") if not spec?

    promises  = (@build(d, depth + 1) for d in spec.dependencies)
    @built[k] = result = Q.all(promises).then (resolved) ->
      Q(spec.provider.apply(@, resolved))
    return result

# Facade for Builder which comprises the public API.
class Injector
  constructor: (module) ->
    builder = new Builder(module)
    for own k, v of module
      do (k, v) =>
        @[k] = -> builder.build(k)

module.exports.Injector = Injector
