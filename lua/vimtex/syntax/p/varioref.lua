local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_varioref() abort
  syntax match texCmdRef '\\Vref\>' nextgroup=texRefArg skipwhite skipnl
endfunction
call VimtexSyntaxPackage_varioref()
delfunction VimtexSyntaxPackage_varioref
  ]==]
end

return M
