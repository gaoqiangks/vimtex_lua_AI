local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_pyluatex() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'python\(q\|repl\)\?',
        \ 'region': 'texPyluatexZone',
        \ 'nested': 'python',
        \})

  highlight def link texCmdPyluatex texCmd
endfunction
call VimtexSyntaxPackage_pyluatex()
delfunction VimtexSyntaxPackage_pyluatex
  ]==]
end

return M
