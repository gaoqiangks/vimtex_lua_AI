local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_optidef() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': '\(arg\)\?\(mini\|maxi\)',
        \ 'starred': v:true,
        \ 'math': v:true,
        \})
  call VimtexSyntaxCore_new_env({
        \ 'name': '\(arg\)\?\(mini[e!]\|maxi\!\)',
        \ 'math': v:true,
        \})
endfunction
call VimtexSyntaxPackage_optidef()
delfunction VimtexSyntaxPackage_optidef
  ]==]
end

return M
