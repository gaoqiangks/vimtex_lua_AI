local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_breqn() abort
  for l:env in ['dmath', 'dseries', 'dgroup', 'darray']
    call VimtexSyntaxCore_new_env(#{
          \ name: l:env,
          \ starred: v:true,
          \ math: v:true
          \})
  endfor
endfunction
call VimtexSyntaxPackage_breqn()
delfunction VimtexSyntaxPackage_breqn
  ]==]
end

return M
