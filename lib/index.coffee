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
      @maxDepth++
      if v instanceof Function
        @specs[k] = {
          args   : getParamNames(v)
          create : v
        }
      else
        throw new Error('Invalid dependency specification') if not (v.args? and v.create?)
        @specs[k] = v

  build: (k, depth = 0) ->
    return @built[k] if @built[k]

    throw new Error('Cycle detected') if depth > @maxDepth

    spec = @specs[k]
    throw new Error("Missing specification for dependency: #{k}") if not spec?

    promises  = (@build(d, depth + 1) for d in spec.args)
    @built[k] = result = Q.all(promises).then (resolved) ->
      Q(spec.create.apply(@, resolved))
    return result

namespace = (module, prefix) ->
  result = {}
  for own k, v of module
    args   = undefined
    create = undefined
    if v instanceof Function
      args   = getParamNames(v)
      create = v
    else
      args   = v.args
      create = v.create
    result[prefix + k] = {
      args   : ((prefix + arg) for arg in args)
      create : create
    }
  result

# Facade for Builder which comprises the public API.
class Injector
  constructor: (module) ->
    builder = new Builder(module)
    for own k, v of module
      do (k, v) =>
        @[k] = -> builder.build(k)

module.exports.Injector = Injector
module.exports.namespace = namespace
