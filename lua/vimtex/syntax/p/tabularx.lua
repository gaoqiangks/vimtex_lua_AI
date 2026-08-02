local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_tabularx() abort
  lua require("vimtex.syntax.packages").load('array')
  " The format is \begin{tabularx}{WIDTH}[POS]{PREAMBLE}
  syntax match texCmdTabularx "\\begin{tabularx}"
        \ skipwhite skipnl
        \ nextgroup=texTabularxWidth
        \ contains=texCmdEnv
  call VimtexSyntaxCore_new_arg('texTabularxWidth', {
        \ 'next': 'texTabularxPreamble,texTabularxOpt,',
        \})
  call VimtexSyntaxCore_new_opt('texTabularxOpt', {
        \ 'next': 'texTabularxPreamble',
        \ 'contains': 'texComment,@NoSpell',
        \})
  call VimtexSyntaxCore_new_arg('texTabularxPreamble', {
        \ 'contains': '@texClusterTabular'
        \})

  highlight def link texTabularxPreamble    texOpt
  highlight def link texTabularxWidth       texLength
  highlight def link texTabularxOpt         texEnvOpt
endfunction
call VimtexSyntaxPackage_tabularx()
delfunction VimtexSyntaxPackage_tabularx
  ]==]
end

return M
