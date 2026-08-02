local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_booktabs() abort
  syntax match texCmdBooktabs "\\\%(top\|mid\|bottom\)rule\>"

  highlight def link texCmdBooktabs texMathDelim
endfunction
call VimtexSyntaxPackage_booktabs()
delfunction VimtexSyntaxPackage_booktabs
  ]==]
end

return M
