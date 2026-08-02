local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_witharrows() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'DispWithArrows',
        \ 'starred': v:true,
        \ 'math': v:true
        \})

  syntax match texMathCmdText "\\Arrow\>"
        \ contained skipwhite nextgroup=texMathTextArg
endfunction
call VimtexSyntaxPackage_witharrows()
delfunction VimtexSyntaxPackage_witharrows
  ]==]
end

return M
