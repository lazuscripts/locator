config = require "locator_config"

import insert, sort from table

-- locates and returns a module, or errors
--  if a path is specified, it will be checked before other paths
--  checks the project root, then each path specified in locator_config
try_require = (name, path) ->
  if path
    ok, value = pcall -> require "#{path}.#{name}"
    return value if ok

  ok, value = pcall -> require name
  return value if ok

  for item in *config
    ok, value = pcall -> require "#{item.path}.#{name}"
    return value if ok

  error "locator could not find '#{name}'"

-- works like Lapis's autoload, but
--  includes trying sub-application paths & can be called to access a value
autoload = (path, tab={}) ->
  return setmetatable tab, {
    __call: (t, name) ->
      t[name] = try_require name, path
      return t[name]
    __index: (t, name) ->
      t[name] = try_require name, path
      return t[name]
  }

-- pass your migrations, it returns them + all sub-application migrations
--  (legacy) see example config for how to specify to not include early migrations
make_migrations = (app_migrations={}) ->
  for item in *config
    ok, migrations = pcall -> require "#{item.path}.migrations"
    if ok
      sorted = {}
      for m in pairs migrations
        insert sorted, m
      sort sorted
      for i in *sorted
        -- only allow migrations after specified config value, or if no 'after' is specified
        if (item.migrations and ((item.migrations.after and i > item.migrations.after) or not item.migrations.after)) or not item.migrations
          -- if your migrations and theirs share a value, combine them
          if app_fn = app_migrations[i]
            app_migrations[i] = (...) ->
              app_fn(...)
              migrations[i](...)
          -- else just add them
          else
            app_migrations[i] = migrations[i]

  return app_migrations

-- sub-applications can define custom functions in a `locator_config` file in
--  their root directory. These functions are aggregated by name and called in
--  the order defined by the paths in the root locator_config
-- note: the root locator_config cannot define any of these
registry = setmetatable {}, {
  __index: (t, name) ->
    registered_functions = {}
    for item in *config
      ok, register = pcall -> require "#{item.path}.locator_config"
      if ok and register[name]
        insert registered_functions, register[name]

    t[name] = (...) ->
      for i=1, #registered_functions-1
        registered_functions[i](...)
      return registered_functions[#registered_functions](...)

    return t[name]
}

-- public interface:
--  functions: autoload, make_migrations
--  tables: locate (locator alias), registry
locator = setmetatable {
  locate: locator, :autoload, :make_migrations, :registry
}, {
  __call: (t, here="") ->
    if "init" == here\sub -4
      here = here\sub 1, -6
    unless here\len! > 0
      here = ""
    return autoload here

  __index: (t, name) ->
    t[name] = autoload name
    return t[name]
}

return locator
