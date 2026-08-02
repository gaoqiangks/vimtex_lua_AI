local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_dot2texi() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'dot2tex',
        \ 'region': 'texDotZone',
        \ 'nested': 'dot'
        \})
endfunction
call VimtexSyntaxPackage_dot2texi()
delfunction VimtexSyntaxPackage_dot2texi
  ]==]
end

return M
