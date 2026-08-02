local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_tikz() abort
  syntax cluster texClusterTikz    contains=texCmdTikz,texTikzEnvBgn,texTikzSemicolon,texTikzDraw,texTikzCycle,texCmd,texGroup,texComment,texPythontexZone
  syntax cluster texClusterTikzset contains=texTikzsetArg,texMathZoneLI,texMathZoneTI,texTypeSize,@texClusterOpt

  syntax match texCmdTikzset "\\tikzset\>"
        \ nextgroup=texTikzsetArg skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texTikzsetArg',
        \ {'contains': '@texClusterTikzset'})

  syntax match texTikzEnvBgn "\\begin{tikzpicture}"
        \ nextgroup=texTikzOpt skipwhite skipnl
        \ contains=texCmdEnv
  call VimtexSyntaxCore_new_env({
        \ 'name': 'tikzpicture',
        \ 'region': 'texTikzZone',
        \ 'contains': '@texClusterTikz',
        \ 'transparent': v:true
        \})
  call VimtexSyntaxCore_new_opt('texTikzOpt',
        \ {'contains': '@texClusterTikzset'})

  syntax keyword texTikzCycle cycle contained
  syntax match texTikzSemicolon ";"  contained
  syntax match texTikzDraw      "--" contained
  syntax match texTikzDraw      "|-" contained
  syntax match texTikzDraw      "-|" contained

  syntax match texCmdTikz "\\node\>" contained nextgroup=texTikzNodeOpt skipwhite skipnl
  call VimtexSyntaxCore_new_opt('texTikzNodeOpt', {'contains': '@texClusterTikzset'})

  highlight def link texCmdTikz       texCmd
  highlight def link texCmdTikzset    texCmd
  highlight def link texTikzNodeOpt   texOpt
  highlight def link texTikzSemicolon texDelim
  highlight def link texTikzDraw      texDelim
  highlight def link texTikzCycle     texMathDelim
  highlight def link texTikzsetArg    texOpt
  highlight def link texTikzOpt       texOpt
endfunction
call VimtexSyntaxPackage_tikz()
delfunction VimtexSyntaxPackage_tikz
  ]==]
end

return M
