local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_zref_clever() abort
  syntax match texCmdZRef "\v\\zc?ref>"
        \ skipwhite skipnl
        \ nextgroup=texZRefArg

  syntax match texCmdZRef "\\zlabel\>"
        \ skipwhite skipnl
        \ nextgroup=texZRefOpt,texRefArg

  call VimtexSyntaxCore_new_arg('texZRefArg', {
        \ 'contains': 'texComment,@NoSpell',
        \})
  call VimtexSyntaxCore_new_opt('texZRefOpt', {
        \ 'next': 'texRefArg',
        \ 'opts': 'oneline',
        \})

  highlight def link texZRefArg           texRefArg
  highlight def link texZRefOpt           texRefOpt
  highlight def link texCmdZRef           texCmdRef
endfunction
call VimtexSyntaxPackage_zref_clever()
delfunction VimtexSyntaxPackage_zref_clever
  ]==]
end

return M
