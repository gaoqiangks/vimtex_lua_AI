local M = {}
local loaded_packages = {}

local addons = {}
for _, pattern in ipairs {
  "lua/vimtex/syntax/p/*.lua",
  "autoload/vimtex/syntax/p/*.vim",
} do
  for _, file in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
    local name = vim.fn.fnamemodify(file, ":t:r")
    if name ~= "init" then
      addons[name] = true
    end
  end
end

local function package_names()
  local state = vim.b.vimtex
  local result = {}
  if type(state) == "table" then
    for name in pairs(state.packages or {}) do
      result[name:lower():gsub("-", "_")] = true
    end
    if state.documentclass then
      result[state.documentclass:lower():gsub("-", "_")] = true
    end
  end
  return result
end

local function load_module(name, config)
  local ok, module = pcall(require, "vimtex.syntax.p." .. name)
  if ok then
    module.load(config)
    return
  end
  local legacy = "vimtex#syntax#p#" .. name .. "#load"
  vim.fn[legacy](config)
end

function M.load(name)
  local buffer = vim.api.nvim_get_current_buf()
  loaded_packages[buffer] = loaded_packages[buffer] or {}
  if loaded_packages[buffer][name] then
    return
  end
  local configs = vim.b.vimtex_syntax
  if type(configs) ~= "table" then
    return
  end
  local config = configs[name]
  if
    type(config) ~= "table"
    or config.__loaded == 1
    or config.__loaded == true
  then
    return
  end
  load_module(name, config)
  loaded_packages[buffer][name] = true
  config.__loaded = 1
  configs[name] = config
  vim.b.vimtex_syntax = configs
end

function M.init()
  if type(vim.b.vimtex) ~= "table" or type(vim.b.vimtex_syntax) ~= "table" then
    return
  end
  local state = vim.b.vimtex
  if type(state.syntax) ~= "table" then
    vim.cmd "let b:vimtex.syntax = {}"
  end
  local installed = package_names()
  local buffer = vim.api.nvim_get_current_buf()
  loaded_packages[buffer] = loaded_packages[buffer] or {}
  local configs = vim.b.vimtex_syntax
  local defaults = vim.g.vimtex_syntax_packages or {}
  for name in pairs(addons) do
    local config = configs[name]
    if type(config) ~= "table" then
      config = vim.tbl_deep_extend("force", {
        load = 1,
        __load = 0,
        __loaded = 0,
      }, defaults[name] or {})
    end
    config.__load = config.load > 1 or (config.load == 1 and installed[name])
    configs[name] = config
  end
  vim.b.vimtex_syntax = configs

  local loaded = 0
  for name, config in pairs(configs) do
    if
      (config.__load == true or config.__load == 1)
      and not loaded_packages[buffer][name]
    then
      load_module(name, config)
      loaded_packages[buffer][name] = true
      configs = vim.b.vimtex_syntax
      config = configs[name] or config
      config.__loaded = 1
      configs[name] = config
      vim.b.vimtex_syntax = configs
      loaded = loaded + 1
    end
  end
  if loaded > 0 then
    vim.fn["VimtexSyntaxCore_init_custom"]()
  end
end

function M.cleanup_buffer(buffer)
  for name in pairs(loaded_packages[buffer] or {}) do
    local module = package.loaded["vimtex.syntax.p." .. name]
    if module and type(module.cleanup_buffer) == "function" then
      pcall(module.cleanup_buffer, buffer)
    end
  end
  loaded_packages[buffer] = nil
end

return M
