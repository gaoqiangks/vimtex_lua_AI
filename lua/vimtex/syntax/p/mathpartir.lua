local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_mathpartir() abort
  call VimtexSyntaxCore_new_env(#{
        \ name: 'mathpar',
        \ math: v:true
        \})
  call VimtexSyntaxCore_new_env(#{
        \ name: 'mathparpagebreakable',
        \ math: v:true
        \})
endfunction
call VimtexSyntaxPackage_mathpartir()
delfunction VimtexSyntaxPackage_mathpartir
  ]==]
end

return M
