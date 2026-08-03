local M = {}

local function enabled()
  return vim.g.vimtex_enabled == nil or vim.g.vimtex_enabled == 1
end

function M.setup()
  if not enabled() or vim.b.did_ftplugin == 1 then
    return
  end

  require("vimtex").setup()
  vim.b.did_ftplugin = 1
  require "vimtex.syntax"

  if vim.g.vimtex_version_check ~= 0 and vim.fn.has "nvim-0.10" == 0 then
    vim.notify("VimTeX requires Neovim 0.10 or later", vim.log.levels.ERROR)
    return
  end

  require("vimtex.main").init()
end

return M
