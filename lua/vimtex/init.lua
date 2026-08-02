local M = {}

function M.init_buffer_module(name)
  local ok, module = pcall(require, "vimtex." .. name)
  if not ok or type(module.init_buffer) ~= "function" then
    return false
  end
  module.init_buffer()
  return true
end

local function enabled()
  return vim.g.vimtex_enabled == nil or vim.g.vimtex_enabled == 1
end

function M.parse_inverse_search_args(args)
  local line, column, file = args:match "^%s*(%d+):(%-?%d+)%s+(.+)$"
  if not line then
    line, file = args:match "^%s*(%d+)%s+(.+)$"
    column = "0"
  end

  if not line or not file then
    return -1, "", 0
  end

  file = vim.trim(file)
  local quote = file:sub(1, 1)
  if (quote == "'" or quote == '"') and file:sub(-1) == quote then
    file = file:sub(2, -2)
  end

  if file == "" then
    return -1, "", 0
  end

  return tonumber(line), file, tonumber(column)
end

function M.setup()
  if not enabled() or vim.g.loaded_vimtex == 1 then
    return
  end

  vim.g.loaded_vimtex = 1
  require "vimtex.syntax"
  require "vimtex.ui"
  require "vimtex.util"

  vim.api.nvim_create_user_command("VimtexInverseSearch", function(opts)
    local line, file, column = M.parse_inverse_search_args(opts.args)
    require("vimtex.view").inverse_search_cmd(line, file, column)
  end, { nargs = "*" })

  require("vimtex.snacks").register()

  local group = vim.api.nvim_create_augroup("vimtex_main", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = require("vimtex.main").quit,
  })
end

return M
