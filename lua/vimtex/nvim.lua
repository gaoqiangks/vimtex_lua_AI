local M = {}

function M.check_treesitter(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].syntax ~= "" then
    return
  end

  local active = require("vim.treesitter.highlighter").active
  if active[bufnr] ~= nil then
    vim.notify(
      "VimTeX syntax highlighting is controlled by Treesitter",
      vim.log.levels.ERROR
    )
  end
end

return M
