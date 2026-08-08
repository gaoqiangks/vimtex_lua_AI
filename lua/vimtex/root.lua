local M = {}

local paths = require "vimtex.paths"

local function has_root_directive()
  local regex = vim.g["vimtex#re#tex_input_root"]
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 20, false)) do
    local lower = line:lower()
    if
      lower:find("tex", 1, true)
      and lower:find("root", 1, true)
      and vim.fn.matchstr(line, regex) ~= ""
    then
      return true
    end
  end
  return false
end

local function add_root()
  if
    vim.bo.filetype ~= "tex"
    or vim.bo.buftype ~= ""
    or not vim.bo.modifiable
    or vim.bo.readonly
    or has_root_directive()
  then
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  local state = vim.b.vimtex
  if file == "" or type(state) ~= "table" or state.tex == "" then
    return
  end

  local main = vim.fn.fnamemodify(state.tex, ":p")
  if main == vim.fn.fnamemodify(file, ":p") then
    return
  end

  local root = paths.relative(main, vim.fn.fnamemodify(file, ":p:h"))
  if root == "" then
    return
  end

  vim.api.nvim_buf_set_lines(0, 0, 0, false, { "% !TeX root = " .. root })
  vim.b.vimtex_root_auto_added = 1
end

function M.init_buffer()
  if vim.g.vimtex_root_auto_add_enabled ~= 1 then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  -- FileType may run before Neovim finalizes BufRead and resets 'modified'.
  -- Defer the insertion so it behaves like a normal user-visible edit.
  vim.schedule(function()
    if
      not vim.api.nvim_buf_is_valid(bufnr)
      or not vim.api.nvim_buf_is_loaded(bufnr)
    then
      return
    end
    vim.api.nvim_buf_call(bufnr, add_root)
  end)
end

return M
