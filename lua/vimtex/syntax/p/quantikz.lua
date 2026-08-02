local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_quantikz() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'quantikz',
        \ 'starred': v:false,
        \ 'math': v:true
        \})
endfunction
call VimtexSyntaxPackage_quantikz()
delfunction VimtexSyntaxPackage_quantikz
  ]==]
end

return M
