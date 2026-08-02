local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_biblatex_chicago() abort
  lua require("vimtex.syntax.packages").load('biblatex')
  syntax match texCmdRef "\\mancite\>"
  syntax match texCmdRef nextgroup=texRefOpts,texRefArgs skipwhite skipnl "\\[hH]eadlesscites\?\>"
endfunction
call VimtexSyntaxPackage_biblatex_chicago()
delfunction VimtexSyntaxPackage_biblatex_chicago
  ]==]
end

return M
