local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_asymptote() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'asy\(def\)\?',
        \ 'region': 'texAsymptoteZone',
        \ 'nested': 'asy',
        \})
endfunction
call VimtexSyntaxPackage_asymptote()
delfunction VimtexSyntaxPackage_asymptote
  ]==]
end

return M
