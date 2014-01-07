_ = require 'lodash'
Q = require 'q'

# http://stackoverflow.com/questions/1007981
STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;
getParamNames = (fn) ->
  fnStr  = fn.toString().replace(STRIP_COMMENTS, '')
  result = fnStr.slice(fnStr.indexOf('(')+1, fnStr.indexOf(')')).match(/([^\s,]+)/g)
  return result || []

isPublicDep = (dep) ->
  _.isFunction(dep) or not dep.private

isValidDep = (dep) ->
  _.isFunction(dep) or dep.create?

addHierarchicalDeps = (module) ->
  module  = _.clone(module)
  newDeps = {}

  for own name, dep of module
    continue if name.indexOf('.') == -1
    continue if not isPublicDep(dep)

    comps = name.split('.')
    for i in [0...(comps.length-1)]
      prefix = comps[0..i].join('.')
      arg    = comps[i + 1]
      newDeps[prefix] ||= {}
      newDeps[prefix][arg] = true

  for own name, args of newDeps
    argNames = _.keys(args)
    do (argNames) ->
      module[name] ||= {
        args   : _.map(argNames, (n) -> name + '.' + n)
        create : (values...) -> _.zipObject(argNames, values)
      }

  module

prefix = (prefix, module) ->
  result = {}
  for own k, v of module
    args   = undefined
    create = undefined
    if _.isFunction(v)
      args   = getParamNames(v)
      create = v
    else
      args   = v.args || []
      create = v.create
    result[prefix + k] = {
      args   : ((prefix + arg) for arg in args)
      create : create
    }
  result

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
        throw new Error('Invalid dependency specification') if not isValidDep(v)
        @specs[k] = v

  build: (k, depth = 0) ->
    return @built[k] if @built[k]

    throw new Error('Cycle detected') if depth > @maxDepth

    spec = @specs[k]
    throw new Error("Missing specification for dependency: #{k}") if not spec?

    args      = spec.args || []
    promises  = (@build(d, depth + 1) for d in args)
    @built[k] = result = Q.all(promises).then (resolved) ->
      Q(spec.create.apply(@, resolved))
    return result

# Facade for Builder which comprises the public API.
class Injector
  constructor: (module, options) ->
    if options?.hierarchical
      module = addHierarchicalDeps(module)

    builder = new Builder(module)
    for own k, v of module
      if isPublicDep(v)
        do (k, v) =>
          @[k] = -> builder.build(k)

module.exports.Injector  = Injector
module.exports.namespace = prefix # (deprecated - get rid of this)
module.exports.prefix    = prefix
