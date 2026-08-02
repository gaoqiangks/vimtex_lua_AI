local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_chemformula() abort
  syntax match texCHSymb contained "->\|+\|-"

  syntax region texCHText matchgroup=texDelim keepend start=/"/ end=/"/
        \ contains=TOP,@NoSpell contained
  syntax region texCHText matchgroup=texDelim keepend start=/'/ end=/'/
        \ contains=TOP,@NoSpell contained

  syntax match texCmdCH "\\ch\>"
        \ nextgroup=texCHOpt,texCHArg skipwhite skipnl
  syntax match texMathCmdCH "\\ch\>" contained
        \ nextgroup=texCHOpt,texCHArg skipwhite skipnl
  call VimtexSyntaxCore_new_opt('texCHOpt', {'next': 'texCHArg'})
  call VimtexSyntaxCore_new_arg('texCHArg', {
        \ 'contains': 'texCmd,texCHArg,texMathZoneTI,texMathZoneLI,texCHSymb,texCHText'
        \})

  syntax cluster texClusterMath add=texMathCmdCH

  highlight def link texCmdCH       texCmd
  highlight def link texMathCmdCH   texMathCmd
  highlight def link texCHOpt       texOpt
  highlight def link texCHArg       texArg
  highlight def link texCHSymb      texSymbol
endfunction
call VimtexSyntaxPackage_chemformula()
delfunction VimtexSyntaxPackage_chemformula
  ]==]
end

return M
