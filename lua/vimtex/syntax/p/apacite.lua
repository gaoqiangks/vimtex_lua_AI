local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_apacite() abort
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl "\v\\citeA[pt]?>\*?"
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl "\v\\Cite[pt]?>\*?"
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl "\v\\[cC]iteal[tp]>\*?"
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl "\v\\cite%(num|text|url)>"
  syntax match texCmdRef nextgroup=texRefOpt,texRefArg skipwhite skipnl "\v\\[Cc]ite%(title|author|year%(par)?|date)?%(NP)?>\*?"

  call VimtexSyntaxCore_new_arg('texRefOpt', {
        \ 'matcher': 'start="<" end=">"',
        \ 'next': 'texRefOpt,texRefArg',
        \})
endfunction
call VimtexSyntaxPackage_apacite()
delfunction VimtexSyntaxPackage_apacite
  ]==]
end

return M
