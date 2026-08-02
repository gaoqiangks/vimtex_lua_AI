local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_pythontex() abort
  call v:lua.require('vimtex.syntax.nested').include('python')

  syntax match texCmdPythontex /\\py[bsc]\?/ nextgroup=texPythontexArg skipwhite skipnl
  call VimtexSyntaxCore_new_arg('texPythontexArg', {
        \ 'contains': '@vimtex_nested_python',
        \ 'opts': 'contained keepend'
        \})
  syntax region texPythontexArg matchgroup=texDelim
        \ start='\z([#@]\)' end='\z1'
        \ contained contains=@vimtex_nested_python keepend

  call VimtexSyntaxCore_new_env({
        \ 'name': 'py\%(block\|code\)',
        \ 'region': 'texPythontexZone',
        \ 'contains': '@vimtex_nested_python'
        \})

  highlight def link texCmdPythontex texCmd
endfunction
call VimtexSyntaxPackage_pythontex()
delfunction VimtexSyntaxPackage_pythontex
  ]==]
end

return M
