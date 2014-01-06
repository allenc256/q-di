var Builder, Injector, Q, STRIP_COMMENTS, getParamNames, namespace,
  __hasProp = {}.hasOwnProperty;

Q = require('q');

STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;

getParamNames = function(fn) {
  var fnStr, result;
  fnStr = fn.toString().replace(STRIP_COMMENTS, '');
  result = fnStr.slice(fnStr.indexOf('(') + 1, fnStr.indexOf(')')).match(/([^\s,]+)/g);
  return result || [];
};

Builder = (function() {
  function Builder(module) {
    var k, v;
    this.built = {};
    this.specs = {};
    this.maxDepth = 0;
    for (k in module) {
      if (!__hasProp.call(module, k)) continue;
      v = module[k];
      this.maxDepth++;
      if (v instanceof Function) {
        this.specs[k] = {
          deps: getParamNames(v),
          create: v
        };
      } else {
        if (!((v.deps != null) && (v.create != null))) {
          throw new Error('Invalid dependency specification');
        }
        this.specs[k] = v;
      }
    }
  }

  Builder.prototype.build = function(k, depth) {
    var d, promises, result, spec;
    if (depth == null) {
      depth = 0;
    }
    if (this.built[k]) {
      return this.built[k];
    }
    if (depth > this.maxDepth) {
      throw new Error('Cycle detected');
    }
    spec = this.specs[k];
    if (spec == null) {
      throw new Error("Missing specification for dependency: " + k);
    }
    promises = (function() {
      var _i, _len, _ref, _results;
      _ref = spec.deps;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        d = _ref[_i];
        _results.push(this.build(d, depth + 1));
      }
      return _results;
    }).call(this);
    this.built[k] = result = Q.all(promises).then(function(resolved) {
      return Q(spec.create.apply(this, resolved));
    });
    return result;
  };

  return Builder;

})();

namespace = function(module, prefix) {
  var arg, create, deps, k, result, v;
  result = {};
  for (k in module) {
    if (!__hasProp.call(module, k)) continue;
    v = module[k];
    deps = void 0;
    create = void 0;
    if (v instanceof Function) {
      deps = getParamNames(v);
      create = v;
    } else {
      deps = v.deps;
      create = v.create;
    }
    result[prefix + k] = {
      deps: (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = deps.length; _i < _len; _i++) {
          arg = deps[_i];
          _results.push(prefix + arg);
        }
        return _results;
      })(),
      create: create
    };
  }
  return result;
};

Injector = (function() {
  function Injector(module) {
    var builder, k, v, _fn,
      _this = this;
    builder = new Builder(module);
    _fn = function(k, v) {
      return _this[k] = function() {
        return builder.build(k);
      };
    };
    for (k in module) {
      if (!__hasProp.call(module, k)) continue;
      v = module[k];
      _fn(k, v);
    }
  }

  return Injector;

})();

module.exports.Injector = Injector;

module.exports.namespace = namespace;
