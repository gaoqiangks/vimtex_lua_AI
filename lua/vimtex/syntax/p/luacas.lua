local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_luacas() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'CAS',
        \ 'region': 'texLuacasZone',
        \})

  highlight def link texLuacasZone texVerbZone
endfunction
call VimtexSyntaxPackage_luacas()
delfunction VimtexSyntaxPackage_luacas
  ]==]
end

return M
