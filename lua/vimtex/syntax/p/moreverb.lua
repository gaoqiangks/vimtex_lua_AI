local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_moreverb() abort
  for l:env in ['verbatimtab', 'verbatimwrite', 'boxedverbatim']
    call VimtexSyntaxCore_new_env({
          \ 'name': l:env,
          \ 'region': 'texVerbZone'
          \})
  endfor
endfunction
call VimtexSyntaxPackage_moreverb()
delfunction VimtexSyntaxPackage_moreverb
  ]==]
end

return M
