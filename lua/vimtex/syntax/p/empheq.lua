local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_empheq() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'empheq',
        \ 'starred': v:true,
        \ 'math': v:true,
        \ 'mtah_nextgroup': 'texEmpheqArg',
        \})
  call VimtexSyntaxCore_new_arg('texEmpheqArg')

  highlight def link texEmpheqArg texOpt
endfunction
call VimtexSyntaxPackage_empheq()
delfunction VimtexSyntaxPackage_empheq
  ]==]
end

return M
