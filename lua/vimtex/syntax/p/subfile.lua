local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_subfile() abort
  syntax match texCmdInput nextgroup=texFileArg skipwhite skipnl "\\subfile\>"
  syntax match texCmdInput nextgroup=texFileArg skipwhite skipnl "\\subfileinclude\>"
endfunction
call VimtexSyntaxPackage_subfile()
delfunction VimtexSyntaxPackage_subfile
  ]==]
end

return M
