var Builder, Injector, Q, STRIP_COMMENTS, addHierarchicalDeps, getParamNames, isPublicDep, isValidDep, prefix, _,
  __hasProp = {}.hasOwnProperty,
  __slice = [].slice;

_ = require('lodash');

Q = require('q');

STRIP_COMMENTS = /((\/\/.*$)|(\/\*[\s\S]*?\*\/))/mg;

getParamNames = function(fn) {
  var fnStr, result;
  fnStr = fn.toString().replace(STRIP_COMMENTS, '');
  result = fnStr.slice(fnStr.indexOf('(') + 1, fnStr.indexOf(')')).match(/([^\s,]+)/g);
  return result || [];
};

isPublicDep = function(dep) {
  return _.isFunction(dep) || !dep["private"];
};

isValidDep = function(dep) {
  return _.isFunction(dep) || (dep.create != null);
};

addHierarchicalDeps = function(module) {
  var arg, argNames, args, comps, dep, i, name, newDeps, prefix, _fn, _i, _ref;
  module = _.clone(module);
  newDeps = {};
  for (name in module) {
    if (!__hasProp.call(module, name)) continue;
    dep = module[name];
    if (name.indexOf('.') === -1) {
      continue;
    }
    if (!isPublicDep(dep)) {
      continue;
    }
    comps = name.split('.');
    for (i = _i = 0, _ref = comps.length - 1; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      prefix = comps.slice(0, +i + 1 || 9e9).join('.');
      arg = comps[i + 1];
      newDeps[prefix] || (newDeps[prefix] = {});
      newDeps[prefix][arg] = true;
    }
  }
  _fn = function(argNames) {
    return module[name] || (module[name] = {
      args: _.map(argNames, function(n) {
        return name + '.' + n;
      }),
      create: function() {
        var values;
        values = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        return _.zipObject(argNames, values);
      }
    });
  };
  for (name in newDeps) {
    if (!__hasProp.call(newDeps, name)) continue;
    args = newDeps[name];
    argNames = _.keys(args);
    _fn(argNames);
  }
  return module;
};

prefix = function(prefix, module) {
  var arg, args, create, k, result, v;
  result = {};
  for (k in module) {
    if (!__hasProp.call(module, k)) continue;
    v = module[k];
    args = void 0;
    create = void 0;
    if (_.isFunction(v)) {
      args = getParamNames(v);
      create = v;
    } else {
      args = v.args || [];
      create = v.create;
    }
    result[prefix + k] = {
      args: (function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          _results.push(prefix + arg);
        }
        return _results;
      })(),
      create: create
    };
  }
  return result;
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
          args: getParamNames(v),
          create: v
        };
      } else {
        if (!isValidDep(v)) {
          throw new Error('Invalid dependency specification');
        }
        this.specs[k] = v;
      }
    }
  }

  Builder.prototype.build = function(k, depth) {
    var args, d, promises, result, spec;
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
    args = spec.args || [];
    promises = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = args.length; _i < _len; _i++) {
        d = args[_i];
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

Injector = (function() {
  function Injector(module, options) {
    var builder, k, v,
      _this = this;
    if (options != null ? options.hierarchical : void 0) {
      module = addHierarchicalDeps(module);
    }
    builder = new Builder(module);
    for (k in module) {
      if (!__hasProp.call(module, k)) continue;
      v = module[k];
      if (isPublicDep(v)) {
        (function(k, v) {
          return _this[k] = function() {
            return builder.build(k);
          };
        })(k, v);
      }
    }
  }

  return Injector;

})();

module.exports.Injector = Injector;

module.exports.namespace = prefix;

module.exports.prefix = prefix;
