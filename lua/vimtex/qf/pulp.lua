local M = { name = "LaTeX logfile using pulp" }

local errorformat = {
  "%-G%*[^ ]) %.%#",
  "%-G%.%#For some reason%.%#",
  "%W%f:%l-%*[0-9?]: %*[^ ] warning: %m",
  "%E%f:%l-%*[0-9?]: %*[^ ] error: %m",
  "%W%f:%l-%*[0-9?]: %m",
  "%W%l-%*[0-9?]: %m",
  "%-G%.%#",
}

function M.addqflist(_, log)
  if not log or log == "" or vim.fn.filereadable(log) == 0 then
    vim.fn.setqflist {}
    error "VimTeX: No log file found"
  end
  local temporary = vim.fn.fnamemodify(log, ":r") .. ".pulp"
  require("vimtex.jobs").run(
    ("pulp %s >%s"):format(
      vim.fn.fnameescape(log),
      vim.fn.fnameescape(temporary)
    )
  )
  local saved = vim.bo.errorformat
  vim.opt_local.errorformat = errorformat
  local ok, message = pcall(
    require("vimtex.qf.util").caddfile,
    vim.fn.fnameescape(temporary),
    saved
  )
  vim.fn.delete(temporary)
  if not ok then
    error(message, 0)
  end
end

return M
