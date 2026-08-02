local paths = require "vimtex.paths"

local M = {}

local version = "cache_v2"
local caches = {}

local Cache = {}
Cache.__index = Cache

local function root()
  if vim.g.vimtex_cache_root then
    return vim.g.vimtex_cache_root
  end
  local base = vim.env.XDG_CACHE_HOME
  if not base or base == "" then
    base = vim.fn.expand "~/.cache"
  end
  return base .. "/vimtex"
end

local function local_name(name)
  local state = vim.b.vimtex
  local filename = type(state) == "table"
      and state.tex
      and vim.fn.fnamemodify(state.tex, ":r")
    or vim.fn.expand "%:p:r"
  filename = filename:gsub("%s+", "_"):gsub("[/\\:]", "%%")
  if #filename > 200 then
    filename = "%..." .. filename:sub(-200)
  end
  return name .. filename
end

function Cache:validate()
  self.__validated = true
  if not vim.deep_equal(self.data.__validate, self.__validation_value) then
    self:clear()
    self.data.__validate = vim.deepcopy(self.__validation_value)
    self:write(true)
  end
end

function Cache:read()
  if self.type == "volatile" then
    return
  end
  local mtime = vim.fn.getftime(self.path)
  if mtime <= self.ftime then
    return
  end

  self.ftime = mtime
  local contents = table.concat(vim.fn.readfile(self.path))
  if contents == "" then
    return
  end

  local ok, decoded = pcall(vim.json.decode, contents)
  if not ok or type(decoded) ~= "table" or vim.islist(decoded) then
    vim.notify(
      "Inconsistent VimTeX cache data: " .. self.path,
      vim.log.levels.WARN
    )
    return
  end
  for key, value in pairs(decoded) do
    self.data[key] = value
  end
  if not self.__validated then
    self:validate()
  end
end

function Cache:get(key)
  self:read()
  if self.data[key] == nil then
    self.data[key] = vim.deepcopy(self.default)
  end
  return self.data[key]
end

function Cache:has(key)
  self:read()
  return self.data[key] ~= nil
end

function Cache:set(key, value)
  self:read()
  self.data[key] = value
  if self.type == "persistent" then
    self:write(true)
  else
    self.ftime = os.time()
  end
  return value
end

function Cache:write(force)
  if self.type == "volatile" then
    return
  end
  self:read()
  if
    not (self.modified == 1 or self.modified == true or force)
    or vim.tbl_isempty(self.data)
  then
    return
  end

  local ok, encoded = pcall(vim.json.encode, self.data)
  if not ok then
    require("vimtex.log").warning(
      "Could not encode VimTeX cache " .. vim.fn.fnamemodify(self.path, ":t:r")
    )
    return
  end
  local written = pcall(vim.fn.writefile, { encoded }, self.path)
  if written then
    self.ftime = vim.fn.getftime(self.path)
    self.modified = 0
  end
end

function Cache:clear()
  if self.type == "persistent" then
    self.data = { __validate = vim.deepcopy(self.__validation_value) }
    vim.fn.delete(self.path)
    self.modified = 0
  else
    self.data = {}
  end
  self.ftime = -1
end

local function create(path, opts)
  local validation = vim.deepcopy(opts.validate)
  if type(validation) == "table" then
    validation._version = version
  end
  local cache = setmetatable({
    type = (opts.persistent == true or opts.persistent == 1) and "persistent"
      or "volatile",
    data = { __validate = vim.deepcopy(validation) },
    path = path,
    ftime = -1,
    default = opts.default,
    modified = 0,
    __validated = false,
    __validation_value = validation,
  }, Cache)
  for name, method in pairs(Cache) do
    if type(method) == "function" then
      cache[name] = function(...)
        local arguments = { ... }
        if arguments[1] == cache then
          table.remove(arguments, 1)
        end
        return method(cache, unpack(arguments))
      end
    end
  end
  return cache
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexClearCache", function(opts)
    M.clear(opts.args)
  end, { nargs = 1 })
end

function M.path(name)
  local directory = root()
  vim.fn.mkdir(directory, "p")
  return paths.join(directory, name)
end

function M.wrap(func, name, opts)
  local cache = M.open(name, opts)
  return function(key)
    if cache:has(key) then
      return cache:get(key)
    end
    return cache:set(key, func(key))
  end
end

function M.open(name, opts)
  opts = vim.tbl_extend("force", {
    ["local"] = false,
    default = 0,
    persistent = vim.g.vimtex_cache_persistent ~= false
      and vim.g.vimtex_cache_persistent ~= 0,
    validate = version,
  }, opts or {})
  name = (opts["local"] == true or opts["local"] == 1) and local_name(name)
    or name
  if not caches[name] then
    caches[name] = create(M.path(name .. ".json"), opts)
  end
  return caches[name]
end

function M.close(name)
  for _, candidate in ipairs { name, local_name(name) } do
    if caches[candidate] then
      caches[candidate]:write()
      caches[candidate] = nil
    end
  end
end

function M.clear(name)
  if not name or name == "" then
    return
  end
  if name == "ALL" then
    caches = {}
    if
      vim.g.vimtex_cache_persistent ~= false
      and vim.g.vimtex_cache_persistent ~= 0
    then
      for _, file in ipairs(vim.fn.globpath(root(), "*.json", false, true)) do
        vim.fn.delete(file)
      end
    end
    return
  end

  for _, candidate in ipairs { name, local_name(name) } do
    if caches[candidate] then
      caches[candidate]:clear()
      caches[candidate] = nil
    elseif
      vim.g.vimtex_cache_persistent ~= false
      and vim.g.vimtex_cache_persistent ~= 0
    then
      vim.fn.delete(M.path(candidate .. ".json"))
    end
  end
end

function M.write_all()
  for _, cache in pairs(caches) do
    cache:write()
  end
end

function M.get(name, key, opts)
  return M.open(name, opts):get(key)
end

function M.set(name, key, value, opts)
  return M.open(name, opts):set(key, value)
end

function M.has(name, key, opts)
  return M.open(name, opts):has(key)
end

function M.write(name, opts)
  M.open(name, opts):write(true)
end

return M
