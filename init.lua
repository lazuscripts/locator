local config = require("locator_config")
local insert, sort
do
  local _obj_0 = table
  insert, sort = _obj_0.insert, _obj_0.sort
end
local check_require
check_require = function(path)
  local ok, value = pcall(function()
    return require(path)
  end)
  if ok or ("string" == type(value) and value:find("module '" .. tostring(path) .. "' not found")) then
    return ok, value
  else
    return error(value)
  end
end
local locate
locate = function(name, path)
  print("locate ->")
  if path then
    print("  try '" .. tostring(path) .. "." .. tostring(name) .. "'")
    local ok, value = check_require(tostring(path) .. "." .. tostring(name))
    if ok then
      return value
    end
  end
  print("  try '" .. tostring(name) .. "'")
  local ok, value = check_require(name)
  if ok then
    return value
  end
  for _index_0 = 1, #config do
    local item = config[_index_0]
    if path then
      print("  try '" .. tostring(item.path) .. "." .. tostring(path) .. "." .. tostring(name) .. "'")
      ok, value = check_require(tostring(item.path) .. "." .. tostring(path) .. "." .. tostring(name))
    else
      print("  try '" .. tostring(item.path) .. "." .. tostring(name) .. "'")
      ok, value = check_require(tostring(item.path) .. "." .. tostring(name))
    end
    if ok then
      return value
    end
  end
  if path then
    return error("locator could not find '" .. tostring(path) .. "." .. tostring(name) .. "'")
  else
    return error("locator could not find '" .. tostring(name) .. "'")
  end
end
local autoload
autoload = function(path, tab)
  if tab == nil then
    tab = { }
  end
  return setmetatable(tab, {
    __call = function(t, name)
      t[name] = locate(name, path)
      return t[name]
    end,
    __index = function(t, name)
      t[name] = locate(name, path)
      return t[name]
    end
  })
end
local make_migrations
make_migrations = function(app_migrations)
  if app_migrations == nil then
    app_migrations = { }
  end
  for _index_0 = 1, #config do
    local item = config[_index_0]
    local ok, migrations = check_require(tostring(item.path) .. ".migrations")
    if ok then
      local sorted = { }
      for m in pairs(migrations) do
        insert(sorted, m)
      end
      sort(sorted)
      for _index_1 = 1, #sorted do
        local i = sorted[_index_1]
        if (item.migrations and ((item.migrations.after and i > item.migrations.after) or not item.migrations.after)) or not item.migrations then
          do
            local app_fn = app_migrations[i]
            if app_fn then
              app_migrations[i] = function(...)
                app_fn(...)
                return migrations[i](...)
              end
            else
              app_migrations[i] = migrations[i]
            end
          end
        end
      end
    end
  end
  return app_migrations
end
local registry = setmetatable({ }, {
  __index = function(t, name)
    local registered_functions = { }
    if config[name] then
      insert(registered_functions, config[name])
    end
    for _index_0 = 1, #config do
      local item = config[_index_0]
      local ok, register = check_require(tostring(item.path) .. ".locator_config")
      if ok and register[name] then
        insert(registered_functions, register[name])
      end
    end
    if #registered_functions > 0 then
      t[name] = function(...)
        for i = 1, #registered_functions - 1 do
          registered_functions[i](...)
        end
        return registered_functions[#registered_functions](...)
      end
    else
      t[name] = function() end
    end
    return t[name]
  end
})
return setmetatable({
  locate = locate,
  autoload = autoload,
  make_migrations = make_migrations,
  registry = registry
}, {
  __call = function(t, here)
    if here and here:find("%.") then
      here = here:sub(1, here:len() - here:match(".*%.(.+)"):len() - 1)
    else
      here = nil
    end
    return autoload(here)
  end,
  __index = function(t, name)
    t[name] = autoload(name)
    return t[name]
  end
})
