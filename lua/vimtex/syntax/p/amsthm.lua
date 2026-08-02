local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_amsthm() abort
  syntax match texCmdNewthm "\\newtheorem\*"
        \ nextgroup=texNewthmArgName skipwhite skipnl

  syntax match texProofEnvBgn "\\begin{proof}"
        \ nextgroup=texProofEnvOpt skipwhite skipnl
        \ contains=texCmdEnv
  call VimtexSyntaxCore_new_opt('texProofEnvOpt', {
        \ 'contains': 'TOP,@NoSpell'
        \})

  syntax match texCmdThmStyle "\\theoremstyle\>"
        \ nextgroup=texThmStyleArg skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texThmStyleArg', {
        \ 'contains': 'TOP,@Spell'
        \})

  highlight def link texCmdThmStyle texCmd
  highlight def link texProofEnvOpt texEnvOpt
  highlight def link texThmStyleArg texArg
endfunction
call VimtexSyntaxPackage_amsthm()
delfunction VimtexSyntaxPackage_amsthm
  ]==]
end

return M
