local M = {}

function M.parse(file)
  if vim.fn.filereadable(file) == 0 then
    return {}
  end

  return vim.fn.readfile(file)
end

return M
