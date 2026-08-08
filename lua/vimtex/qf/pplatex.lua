local M = { name = "LaTeX logfile using pplatex" }

local errorformat = {
  "%E** Error   in %f, Line %l:%m",
  "%W** Warning in %f, Line %l:%m",
  "%I** BadBox  in %f, Line %l:%m",
  "%E** Error   , Line %l:%m",
  "%W** Warning, Line %l:%m",
  "%I** BadBox  , Line %l:%m",
  "%E** Error   in %f, Line %l:%m",
  "%W** Warning in %f, Line %l:%m",
  "%E** Error   in %f:%m",
  "%W** Warning in %f:%m",
  "%I** BadBox  in %f:%m",
  "%E** Error in %f:%m",
  "%W** Warning in %f:%m",
  "%W** Warning: %m on input line %*#%l.",
  "%W** Warning:  %m",
  "%W** Warning: %m",
  "%W** Warning: ",
  "%E** Error  :%m",
  "%C %*#%m on input line %*#%l.",
  "%C %*#%m",
  "%-Z",
  "%-GResult%.%#",
  "%-G%.%#",
}

function M.addqflist(_, log)
  if not log or log == "" or vim.fn.filereadable(log) == 0 then
    error "VimTeX: No log file found"
  end
  local temporary = vim.fn.fnamemodify(log, ":r") .. ".pplatex"
  require("vimtex.jobs").run(('pplatex -i "%s" >"%s"'):format(log, temporary))
  require("vimtex.paths").pushd(vim.b.vimtex.root)
  local saved = vim.bo.errorformat
  vim.opt_local.errorformat = errorformat
  local ok, message = pcall(
    require("vimtex.qf.util").caddfile,
    vim.fn.fnameescape(temporary),
    saved
  )
  require("vimtex.paths").popd()
  vim.fn.delete(temporary)
  if not ok then
    error(message, 0)
  end
end

return M
