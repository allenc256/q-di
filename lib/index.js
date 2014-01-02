var Builder, Injector, Q, STRIP_COMMENTS, getParamNames,
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
      if (v instanceof Function) {
        this.maxDepth++;
        this.specs[k] = {
          dependencies: getParamNames(v),
          provider: v
        };
      } else {
        this.built[k] = Q(v);
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
      _ref = spec.dependencies;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        d = _ref[_i];
        _results.push(this.build(d, depth + 1));
      }
      return _results;
    }).call(this);
    this.built[k] = result = Q.all(promises).then(function(resolved) {
      return Q(spec.provider.apply(this, resolved));
    });
    return result;
  };

  return Builder;

})();

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
