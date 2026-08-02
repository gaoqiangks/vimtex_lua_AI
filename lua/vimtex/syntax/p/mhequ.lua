local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_mhequ() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'equs\?',
        \ 'starred': v:true,
        \ 'math': v:true
        \})
endfunction
call VimtexSyntaxPackage_mhequ()
delfunction VimtexSyntaxPackage_mhequ
  ]==]
end

return M
