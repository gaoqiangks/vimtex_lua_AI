local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_gnuplottex() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'gnuplot',
        \ 'region': 'texGnuplotZone',
        \ 'nested': 'gnuplot'
        \})
endfunction
call VimtexSyntaxPackage_gnuplottex()
delfunction VimtexSyntaxPackage_gnuplottex
  ]==]
end

return M
