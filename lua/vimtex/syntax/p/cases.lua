local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_cases() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': '\(sub\)\?numcases',
        \ 'math': v:true,
        \})
endfunction
call VimtexSyntaxPackage_cases()
delfunction VimtexSyntaxPackage_cases
  ]==]
end

return M
