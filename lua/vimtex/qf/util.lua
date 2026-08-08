local M = {}

function M.caddfile(file, errorformat)
  local ok, message = pcall(vim.cmd, "noautocmd caddfile " .. file)
  vim.opt_local.errorformat = errorformat
  if not ok then
    error(message, 0)
  end
end

return M
