local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_nameref() abort
  syntax match texCmdNameref '\\nameref\>' nextgroup=texRefOpt,texRefArg

  highlight def link texCmdNameref texCmdRef
endfunction
call VimtexSyntaxPackage_nameref()
delfunction VimtexSyntaxPackage_nameref
  ]==]
end

return M
