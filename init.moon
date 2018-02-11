config = require "locator_config"

import insert, sort from table

-- locates and returns a module, or errors
--  if priority (path) specified, will check it before other paths
--  checks project root first, then each path specified in locator_config
try_require = (path, priority) ->
  if priority
    ok, value = pcall -> require "#{priority}.#{path}"
    return value if ok

  ok, value = pcall -> require path
  return value if ok

  for item in *config
    ok, value = pcall -> require "#{item.path}.#{path}"
    return value if ok

  error "locator could not find '#{path}'"

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

-- return access to autoload and migrations functions,
--  and metamethods for getting autoloaders
return setmetatable {
  :autoload, :make_migrations
}, {
  __call: (t, here) ->
    if "init" == here\sub -4
      here = here\sub 1, -6
    unless here
      here = ""
    return autoload here

  __index: (t, name) ->
    t[name] = autoload name
    return t[name]
}
