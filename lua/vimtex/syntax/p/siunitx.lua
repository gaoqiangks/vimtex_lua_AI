local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_siunitx() abort
  syntax match texSIDelim contained "[;x]"
  syntax match texSICmd contained "\\\w\+\>"

  syntax match texCmdSI nextgroup=texSIOptU,texSIArgUnit skipwhite "\\si\>"
  syntax match texCmdSI nextgroup=texSIOptU,texSIArgUnit skipwhite "\\unit\>"
  call VimtexSyntaxCore_new_opt('texSIOptU', {'contains': '', 'next': 'texSIArgUnit'})
  call VimtexSyntaxCore_new_arg('texSIArgUnit', {'contains': 'texSICmd,texSIArgUnit'})

  syntax match texCmdSI nextgroup=texSIOptN,texSIArgNum skipwhite "\\num\(list\)\?\>"
  syntax match texCmdSI nextgroup=texSIOptN,texSIArgNum skipwhite "\\ang\>"
  call VimtexSyntaxCore_new_opt('texSIOptN', {'contains': '', 'next': 'texSIArgNum'})
  call VimtexSyntaxCore_new_arg('texSIArgNum', {'contains': 'texSIDelim'})

  syntax match texCmdSI nextgroup=texSIOptNN,texSIArgNumN skipwhite "\\numrange\>"
  call VimtexSyntaxCore_new_opt('texSIOptNN', {'contains': '', 'next': 'texSIArgNumN'})
  call VimtexSyntaxCore_new_arg('texSIArgNumN', {'contains': 'texSIDelim'})

  syntax match texCmdSI nextgroup=texSIOptNU,texSIArgNumU skipwhite "\\SI\(list\)\?\>"
  syntax match texCmdSI nextgroup=texSIOptNU,texSIArgNumU skipwhite "\\qty\(list\)\?\>"
  call VimtexSyntaxCore_new_opt('texSIOptNU', {'contains': '', 'next': 'texSIArgNumU'})
  call VimtexSyntaxCore_new_arg('texSIArgNumU', {'contains': 'texSIDelim', 'next': 'texSIArgUnit'})

  syntax match texCmdSI nextgroup=texSIOptNNU,texSIArgNumNU skipwhite "\\SIrange\>"
  syntax match texCmdSI nextgroup=texSIOptNNU,texSIArgNumNU skipwhite "\\qtyrange\>"
  call VimtexSyntaxCore_new_opt('texSIOptNNU', {'contains': '', 'next': 'texSIArgNumNU'})
  call VimtexSyntaxCore_new_arg('texSIArgNumNU', {'contains': 'texSIDelim', 'next': 'texSIArgNumU'})

  syntax match texMathCmdSI contained nextgroup=texSIOptU,texSIArgUnit skipwhite "\\si\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptU,texSIArgUnit skipwhite "\\unit\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptN,texSIArgNum skipwhite "\\num\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptNU,texSIArgNumU skipwhite "\\SI\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptNU,texSIArgNumU skipwhite "\\qty\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptNNU,texSIArgNumNU skipwhite "\\SIrange\>"
  syntax match texMathCmdSI contained nextgroup=texSIOptNNU,texSIArgNumNU skipwhite "\\qtyrange\>"
  syntax cluster texClusterMath add=texMathCmdSI

  highlight def link texCmdSI       texCmd
  highlight def link texMathCmdSI   texMathCmd
  highlight def link texSICmd       texMathCmd
  highlight def link texSIDelim     texSymbol
  highlight def link texSIOpt       texOpt
  highlight def link texSIOptU      texSIOpt
  highlight def link texSIOptN      texSIOpt
  highlight def link texSIOptNU     texSIOpt
  highlight def link texSIOptNNU    texSIOpt
  highlight def link texSIArgUnit   texArg
  highlight def link texSIArgNum    texLength
  highlight def link texSIArgNumN   texSIArgNum
  highlight def link texSIArgNumU   texSIArgNum
  highlight def link texSIArgNumNU  texSIArgNum
  highlight def link texSIArgNumNNU texSIArgNum
endfunction
call VimtexSyntaxPackage_siunitx()
delfunction VimtexSyntaxPackage_siunitx
  ]==]
end

return M
