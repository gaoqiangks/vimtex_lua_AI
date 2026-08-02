local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_glossaries() abort
  syntax match texCmdGls "\v\c\\gls%(desc|link|pl)?>"
        \ nextgroup=texGlsArg skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texGlsArg', {'contains': '@NoSpell'})

  " \newacronym -> opt -> arg1 -> arg2 -> arg3
  syntax match texCmdNewAcr "\\newacronym\>"
        \ nextgroup=texNewAcrOpt,texNewAcrArgLabel skipwhite skipnl
  call VimtexSyntaxCore_new_opt('texNewAcrOpt', {
        \ 'next': 'texNewAcrArgLabel',
        \})
  call VimtexSyntaxCore_new_arg('texNewAcrArgLabel', {
        \ 'next': 'texNewAcrArgAbbr',
        \ 'contains': '@NoSpell',
        \})
  call VimtexSyntaxCore_new_arg('texNewAcrArgAbbr', {
        \ 'next': 'texNewAcrArgLong',
        \ 'contains': '@NoSpell',
        \})
  call VimtexSyntaxCore_new_arg('texNewAcrArgLong')

  " \acrcmds -> ArgLabel
  syntax match texCmdAcr
        \ "\v\\%(ACR|Acr|acr)%(full|long|short)%(pl)?>"
        \ nextgroup=texAcrArgLabel skipwhite skipnl
  syntax match texCmdAcr "\\acrfullfmt"
        \ nextgroup=texAcrArgLabel skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texAcrArgLabel', {'contains': '@NoSpell'})

  highlight def link texCmdGls         texCmd
  highlight def link texGlsArg         texRefArg
  highlight def link texCmdAcr         texCmd
  highlight def link texCmdNewAcr      texCmdNew
  highlight def link texNewAcrOpt      texOpt
  highlight def link texNewAcrArgLabel texArg
  highlight def link texAcrArgLabel    texNewAcrArgLabel
endfunction
call VimtexSyntaxPackage_glossaries()
delfunction VimtexSyntaxPackage_glossaries
  ]==]
end

return M
