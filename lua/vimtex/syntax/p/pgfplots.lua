local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_pgfplots() abort
  lua require("vimtex.syntax.packages").load('tikz')
  syntax cluster texClusterTikz add=texCmdAxis

  syntax match texCmdTikzset nextgroup=texTikzsetArg skipwhite "\\pgfplotsset\>"

  syntax match texTikzEnvBgn contains=texCmdEnv nextgroup=texTikzOpt skipwhite skipnl "\\begin{\%(log\)*axis}"
  syntax match texTikzEnvBgn contains=texCmdEnv nextgroup=texTikzOpt skipwhite skipnl "\\begin{groupplot}"
  for l:env in ['axis', 'logaxis', 'loglogaxis', 'groupplot']
    call VimtexSyntaxCore_new_env({
          \ 'name': l:env,
          \ 'region': 'texTikzZone',
          \ 'contains': '@texClusterTikz',
          \ 'transparent': v:true,
          \})
  endfor


  syntax match texCmdAxis contained nextgroup=texTikzOpt skipwhite skipnl "\\nextgroupplot\>"
  syntax match texCmdAxis contained nextgroup=texPgfAddplotOpt,texPgfType,texPgfFunc skipwhite skipnl "\\addplot3\?\>+\?"

  call VimtexSyntaxCore_new_opt('texPgfAddplotOpt', {'contains': '@texClusterTikzset', 'next': 'texPgfType,texPgfFunc'})
  call VimtexSyntaxCore_new_arg('texPgfFunc', {'contains': '', 'opts': 'contained transparent'})


  syntax match texPgfType "table" contained nextgroup=texPgfTableOpt,texPgfTableArg skipwhite skipnl
  call VimtexSyntaxCore_new_opt('texPgfTableOpt', {'contains': '@texClusterTikzset'})
  call VimtexSyntaxCore_new_arg('texPgfTableArg', {'contains': '@NoSpell,texComment'})


  syntax match texPgfType "gnuplot" contained nextgroup=texPgfGnuplotArg skipwhite skipnl
  call v:lua.require('vimtex.syntax.nested').include('gnuplot')
  call VimtexSyntaxCore_new_arg('texPgfGnuplotArg', {'contains': '@vimtex_nested_gnuplot', 'next': 'texPgfNode'})


  syntax match texPgfType "coordinates" contained nextgroup=texPgfCoordinates skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texPgfCoordinates', {
        \ 'contains': 'texComment'
        \})


  syntax match texPgfNode "node" contained nextgroup=texTikzNodeOpt skipwhite skipnl


  highlight def link texCmdAxis        texCmd
  highlight def link texPgfNode        texCmd
  highlight def link texPgfType        texMathDelim
  highlight def link texPgfFunc        texArg
  highlight def link texPgfTableArg    texFileArg
  highlight def link texPgfCoordinates texOpt
  highlight def link texPgfAddplotOpt  texOpt
  highlight def link texPgfTableOpt    texOpt
endfunction
call VimtexSyntaxPackage_pgfplots()
delfunction VimtexSyntaxPackage_pgfplots
  ]==]
end

return M
