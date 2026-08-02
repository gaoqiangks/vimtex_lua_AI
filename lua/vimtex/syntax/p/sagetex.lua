local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_sagetex() abort
  call v:lua.require('vimtex.syntax.nested').include('python')

  syntax match texCmdSagetex /\\sageplot\>/
        \ nextgroup=texSagetexOpt,texSagetexArg skipwhite skipnl

  call VimtexSyntaxCore_new_arg('texSagetexArg', {
        \ 'contains': '@vimtex_nested_python',
        \ 'opts': 'contained keepend'
        \})
  call v:lua.require('vimtex.syntax').add_to_mathzone_ignore('texSagetexArg')
  call VimtexSyntaxCore_new_opt('texSagetexOpt', {'next': 'texSagetexArg'})

  for l:env_name in [
        \ 'sageblock',
        \ 'sagesilent',
        \ 'sageverbatim',
        \ 'sageexample',
        \ 'sagecommandline'
        \]
    call VimtexSyntaxCore_new_env({
          \ 'name': l:env_name,
          \ 'region': 'texSagetexZone',
          \ 'contains': '@vimtex_nested_python'
          \})
  endfor

  " The following commands are supported inside and outside of math zones
  for l:cmd_name in ['sage', 'sagestr']
    for l:in_mathmode in [v:true, v:false]
      call VimtexSyntaxCore_new_cmd({
            \ 'name': l:cmd_name,
            \ 'mathmode': l:in_mathmode,
            \ 'nextgroup': 'texSagetexArg'
            \})
    endfor
  endfor

  highlight def link texCmdSagetex texCmd
endfunction
call VimtexSyntaxPackage_sagetex()
delfunction VimtexSyntaxPackage_sagetex
  ]==]
end

return M
