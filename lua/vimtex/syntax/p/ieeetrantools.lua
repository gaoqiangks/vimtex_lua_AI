local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_ieeetrantools() abort
  call VimtexSyntaxCore_new_arg('texMathEnvIEEEArg')
  call VimtexSyntaxCore_new_opt('texMathEnvIEEEOpt',
        \ {'next': 'texMathEnvIEEEArg'})
  for l:env in ['IEEEeqnarray', 'IEEEeqnarrayboxm']
    call VimtexSyntaxCore_new_env({
          \ 'name': l:env,
          \ 'starred': v:true,
          \ 'math': v:true,
          \ 'math_nextgroup': 'texMathEnvIEEEOpt,texMathEnvIEEEArg',
          \})
  endfor

  highlight def link texMathEnvIEEEArg texArg
  highlight def link texMathEnvIEEEOpt texOpt
endfunction
call VimtexSyntaxPackage_ieeetrantools()
delfunction VimtexSyntaxPackage_ieeetrantools
  ]==]
end

return M
