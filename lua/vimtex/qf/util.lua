local M = {}

function M.caddfile(file, errorformat)
  vim.cmd("noautocmd caddfile " .. file)
  vim.opt_local.errorformat = errorformat
end

return M
